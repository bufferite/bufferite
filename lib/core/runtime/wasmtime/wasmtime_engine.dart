import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'wasmtime_ffi.dart';

/// Kesalahan engine (bukan kesalahan program Lua).
final class WasmtimeException implements Exception {
  WasmtimeException(this.message);

  final String message;

  @override
  String toString() => 'WasmtimeException: $message';
}

/// Hasil satu eksekusi modul WASI (`_start`).
final class WasmRunResult {
  const WasmRunResult({
    required this.stdout,
    required this.stderr,
    this.exitCode,
    this.errorMessage,
    this.trapMessage,
  });

  final String stdout;
  final String stderr;
  final int? exitCode;
  final String? errorMessage;
  final String? trapMessage;

  bool get isSuccess => exitCode == 0 && errorMessage == null;

  String get failureMessage {
    final stderrText = stderr.trim();
    if (stderrText.isNotEmpty) {
      return stderrText;
    }
    final error = errorMessage?.trim();
    if (error != null && error.isNotEmpty) {
      return error;
    }
    final trap = trapMessage?.trim();
    if (trap != null && trap.isNotEmpty) {
      return trap;
    }
    return 'Modul WASI keluar dengan kode ${exitCode ?? 'tidak diketahui'}.';
  }
}

/// Modul WASM yang sudah dikompilasi; harus [close] setelah selesai.
final class WasmtimeModule {
  WasmtimeModule._(this._ffi, this._pointer);

  final WasmtimeFfi _ffi;
  final Pointer<WasmtimeModuleOpaque> _pointer;
  var _closed = false;

  bool get isClosed => _closed;

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _ffi.moduleDelete(_pointer);
  }
}

/// Engine wasmtime + konfigurasi sandbox (EH, epoch, batas stack).
///
/// `incrementEpoch` aman dipanggil dari isolate lain memakai [address] untuk
/// memicu trap saat batas waktu habis (wasmtime merancang epoch sebagai
/// interupsi lintas thread).
final class WasmtimeEngine {
  WasmtimeEngine({
    WasmtimeFfi? ffi,
    String? libraryPath,
  }) : _ffi = ffi ?? WasmtimeFfi.open(path: libraryPath) {
    final config = _ffi.configNew();
    if (config == nullptr) {
      throw WasmtimeException('Gagal membuat konfigurasi wasmtime.');
    }
    try {
      _ffi.configWasmExceptionsSet(config, 1);
      _ffi.configEpochInterruptionSet(config, 1);
      _engine = _ffi.engineNewWithConfig(config);
    } finally {
      // wasm_engine_new_with_config mengambil alih kepemilikan config.
    }
    if (_engine == nullptr) {
      throw WasmtimeException('Gagal membuat engine wasmtime.');
    }
  }

  final WasmtimeFfi _ffi;
  late final Pointer<WasmEngineOpaque> _engine;
  var _closed = false;

  Pointer<WasmEngineOpaque> get pointer => _engine;

  /// Alamat engine untuk dipakai isolate lain lewat [incrementEpochAt].
  int get address => _engine.address;

  static void incrementEpochAt(WasmtimeFfi ffi, int address) {
    ffi.engineIncrementEpoch(Pointer<WasmEngineOpaque>.fromAddress(address));
  }

  void incrementEpoch() => _ffi.engineIncrementEpoch(_engine);

  bool get isClosed => _closed;

  WasmtimeModule compile(Uint8List bytes) {
    if (_closed) {
      throw WasmtimeException('Engine sudah ditutup.');
    }
    final data = calloc<Uint8>(bytes.isEmpty ? 1 : bytes.length);
    try {
      data.asTypedList(bytes.length).setAll(0, bytes);
      final out = calloc<Pointer<WasmtimeModuleOpaque>>();
      try {
        final error = _ffi.moduleNew(_engine, data, bytes.length, out);
        if (error != nullptr) {
          throw WasmtimeException(_readError(error));
        }
        final module = out.value;
        if (module == nullptr) {
          throw WasmtimeException('wasmtime tidak mengembalikan modul.');
        }
        return WasmtimeModule._(_ffi, module);
      } finally {
        calloc.free(out);
      }
    } finally {
      calloc.free(data);
    }
  }

  /// Jalankan `_start` dengan argv dan tangkap stdout/stderr.
  ///
  /// [memoryLimitBytes] berlaku per store (batas pertumbuhan memori linear).
  WasmRunResult run(
    WasmtimeModule module,
    List<String> argv, {
    int memoryLimitBytes = 64 * 1024 * 1024,
    int epochDeadline = 1,
    Uint8List? stdinBytes,
  }) {
    if (_closed) {
      throw WasmtimeException('Engine sudah ditutup.');
    }
    if (module.isClosed) {
      throw WasmtimeException('Modul sudah ditutup.');
    }

    final tempDir = Directory.systemTemp.createTempSync('bufferite_wasm_');
    final stdoutFile = File('${tempDir.path}${Platform.pathSeparator}stdout');
    final stderrFile = File('${tempDir.path}${Platform.pathSeparator}stderr');

    Pointer<WasmtimeStoreOpaque>? store;
    Pointer<WasmtimeLinkerOpaque>? linker;
    Pointer<WasmtimeInstance>? instance;
    Pointer<Pointer<WasmTrapOpaque>>? trap;
    Pointer<WasmtimeExtern>? item;
    Pointer<Utf8>? startName;
    Pointer<Utf8>? stdoutPath;
    Pointer<Utf8>? stderrPath;

    try {
      store = _ffi.storeNew(_engine, nullptr, nullptr);
      if (store == nullptr) {
        throw WasmtimeException('Gagal membuat store wasmtime.');
      }
      _ffi.storeLimiter(store, memoryLimitBytes, -1, -1, -1, -1);
      final context = _ffi.storeContext(store);

      final wasi = _ffi.wasiConfigNew();
      if (wasi == nullptr) {
        throw WasmtimeException('Gagal membuat konfigurasi WASI.');
      }
      stdoutPath = stdoutFile.path.toNativeUtf8();
      stderrPath = stderrFile.path.toNativeUtf8();
      if (_ffi.wasiConfigSetStdoutFile(wasi, stdoutPath) == 0) {
        throw WasmtimeException('Gagal membuka stdout WASI.');
      }
      if (_ffi.wasiConfigSetStderrFile(wasi, stderrPath) == 0) {
        throw WasmtimeException('Gagal membuka stderr WASI.');
      }
      final argvPointers = calloc<Pointer<Utf8>>(argv.isEmpty ? 1 : argv.length);
      final owned = <Pointer<Utf8>>[];
      try {
        for (var i = 0; i < argv.length; i++) {
          final value = argv[i].toNativeUtf8();
          owned.add(value);
          argvPointers[i] = value;
        }
        if (_ffi.wasiConfigSetArgv(wasi, argv.length, argvPointers) == 0) {
          throw WasmtimeException('Argumen WASI bukan UTF-8 yang valid.');
        }
      } finally {
        for (final value in owned) {
          malloc.free(value);
        }
        calloc.free(argvPointers);
      }

      if (stdinBytes != null) {
        // `wasm_byte_vec_new` menyalin byte ke Vec milik Rust;
        // `wasi_config_set_stdin_bytes` mengambil alih Vec tersebut.
        final vec = calloc<WasmByteVec>();
        Pointer<Uint8>? data;
        if (stdinBytes.isNotEmpty) {
          data = calloc<Uint8>(stdinBytes.length);
          data.asTypedList(stdinBytes.length).setAll(0, stdinBytes);
        }
        try {
          _ffi.byteVecNew(vec, stdinBytes.length, data ?? nullptr);
        } finally {
          if (data != null) {
            calloc.free(data);
          }
        }
        _ffi.wasiConfigSetStdinBytes(wasi, vec);
        calloc.free(vec);
      }

      final wasiError = _ffi.contextSetWasi(context, wasi);
      if (wasiError != nullptr) {
        throw WasmtimeException(_readError(wasiError));
      }

      // Deadline relatif terhadap epoch engine saat ini. Host menaikkan epoch
      // untuk timeout/pembatalan; worker meneruskan deadline berikutnya agar
      // store baru tidak langsung trap setelah satu interupsi.
      _ffi.contextSetEpochDeadline(context, epochDeadline);

      linker = _ffi.linkerNew(_engine);
      if (linker == nullptr) {
        throw WasmtimeException('Gagal membuat linker wasmtime.');
      }
      final defineError = _ffi.linkerDefineWasi(linker);
      if (defineError != nullptr) {
        throw WasmtimeException(_readError(defineError));
      }

      instance = calloc<WasmtimeInstance>();
      trap = calloc<Pointer<WasmTrapOpaque>>();
      final instantiateError = _ffi.linkerInstantiate(
        linker,
        context,
        module._pointer,
        instance,
        trap,
      );
      if (instantiateError != nullptr) {
        throw WasmtimeException(_readError(instantiateError));
      }
      _throwIfTrapped(trap);

      item = calloc<WasmtimeExtern>();
      startName = '_start'.toNativeUtf8();
      if (_ffi.instanceExportGet(context, instance, startName, 6, item) == 0) {
        throw WasmtimeException('Modul tidak mengekspor `_start`.');
      }

      final callError = _ffi.funcCall(
        context,
        // `wasmtime_extern_t.of.func` berada di offset 8 (diuji di test layout).
        Pointer<WasmtimeFunc>.fromAddress(item.address + 8),
        nullptr,
        0,
        nullptr,
        0,
        trap,
      );
      final call = _describeCall(callError, trap);
      // Tutup store dulu agar wasmtime menutup file stdout/stderr (flush).
      _ffi.storeDelete(store);
      store = null;
      return WasmRunResult(
        stdout: _readFile(stdoutFile),
        stderr: _readFile(stderrFile),
        exitCode: call.exitCode,
        errorMessage: call.errorMessage,
        trapMessage: call.trapMessage,
      );
    } finally {
      if (startName != null) {
        malloc.free(startName);
      }
      if (stdoutPath != null) {
        malloc.free(stdoutPath);
      }
      if (stderrPath != null) {
        malloc.free(stderrPath);
      }
      if (item != null) {
        calloc.free(item);
      }
      if (trap != null) {
        _deleteTrap(trap);
        calloc.free(trap);
      }
      if (instance != null) {
        calloc.free(instance);
      }
      if (linker != null) {
        _ffi.linkerDelete(linker);
      }
      if (store != null) {
        _ffi.storeDelete(store);
      }
      _deleteTempDir(tempDir);
    }
  }

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _ffi.engineDelete(_engine);
  }

  void _throwIfTrapped(Pointer<Pointer<WasmTrapOpaque>> trap) {
    final value = trap.value;
    if (value == nullptr) {
      return;
    }
    final message = _readTrap(value);
    _ffi.trapDelete(value);
    trap.value = nullptr;
    throw WasmtimeException(message);
  }

  _CallOutcome _describeCall(
    Pointer<WasmtimeErrorOpaque> error,
    Pointer<Pointer<WasmTrapOpaque>> trap,
  ) {
    if (error != nullptr) {
      final status = calloc<Int32>();
      try {
        final isExit = _ffi.errorExitStatus(error, status) != 0;
        if (isExit) {
          final code = status.value;
          _ffi.errorDelete(error);
          return _CallOutcome(exitCode: code);
        }
        final message = _readError(error);
        return _CallOutcome(errorMessage: message);
      } finally {
        calloc.free(status);
      }
    }
    final value = trap.value;
    if (value != nullptr) {
      final message = _readTrap(value);
      _ffi.trapDelete(value);
      trap.value = nullptr;
      final exit = _parseExitCode(message);
      if (exit != null) {
        return _CallOutcome(exitCode: exit);
      }
      return _CallOutcome(trapMessage: message);
    }
    return const _CallOutcome(exitCode: 0);
  }

  static int? _parseExitCode(String message) {
    final match = RegExp(r'exited with code (\d+)').firstMatch(message);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }

  void _deleteTrap(Pointer<Pointer<WasmTrapOpaque>> trap) {
    final value = trap.value;
    if (value != nullptr) {
      _ffi.trapDelete(value);
      trap.value = nullptr;
    }
  }

  String _readError(Pointer<WasmtimeErrorOpaque> error) {
    final vec = calloc<WasmByteVec>();
    try {
      _ffi.errorMessage(error, vec);
      final message = _decodeVec(vec);
      _ffi.byteVecDelete(vec);
      return message;
    } finally {
      _ffi.errorDelete(error);
      calloc.free(vec);
    }
  }

  String _readTrap(Pointer<WasmTrapOpaque> trap) {
    final vec = calloc<WasmByteVec>();
    try {
      _ffi.trapMessage(trap, vec);
      final message = _decodeVec(vec);
      _ffi.byteVecDelete(vec);
      return message;
    } finally {
      calloc.free(vec);
    }
  }

  static String _decodeVec(Pointer<WasmByteVec> vec) {
    final size = vec.ref.size;
    if (size <= 0) {
      return '';
    }
    return _decodeBytes(vec.ref.data, size);
  }

  static String _readFile(File file) {
    if (!file.existsSync()) {
      return '';
    }
    return utf8.decode(file.readAsBytesSync(), allowMalformed: true);
  }

  static void _deleteTempDir(Directory dir) {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // File sementara bisa masih dipegang; OS membersihkan nanti.
    }
  }

  static String _decodeBytes(Pointer<Uint8> data, int size) {
    final bytes = Uint8List.fromList(data.asTypedList(size));
    var end = bytes.length;
    while (end > 0 && bytes[end - 1] == 0) {
      end--;
    }
    return utf8.decode(bytes.sublist(0, end), allowMalformed: true);
  }
}

final class _CallOutcome {
  const _CallOutcome({this.exitCode, this.errorMessage, this.trapMessage});

  final int? exitCode;
  final String? errorMessage;
  final String? trapMessage;
}
