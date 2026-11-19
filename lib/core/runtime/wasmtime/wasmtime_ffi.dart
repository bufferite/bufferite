import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Override path ke library native wasmtime (berguna untuk dev/Android).
const String wasmtimeLibraryEnv = 'BUFFERITE_WASMTIME_LIB';

/// `wasm_byte_vec_t` (dipakai juga sebagai `wasm_name_t`).
///
/// Layout C: `{ size_t size; byte_t *data; }`.
final class WasmByteVec extends Struct {
  @IntPtr()
  external int size;

  external Pointer<Uint8> data;
}

/// `wasmtime_func_t`: `{ u64 store_id; void *__private; }`.
///
/// `wasmtime_func_call` menerima pointer ke struct ini, bukan `wasmtime_extern_t`.
final class WasmtimeFunc extends Struct {
  @Uint64()
  external int storeId;

  external Pointer<Void> privateData;
}

/// `wasmtime_extern_t`: kind (u8) + padding + union `of` (24 byte).
///
/// Field `of.func` (`wasmtime_func_t`) berada di offset 8, jadi struct ini
/// memetakannya langsung.
final class WasmtimeExtern extends Struct {
  @Uint8()
  external int kind;

  @Array(7)
  external Array<Uint8> padding;

  @Uint64()
  external int storeId;

  external Pointer<Void> privateData;

  @Uint64()
  external int reserved;
}

/// `wasmtime_instance_t`: `{ u64 store_id; size_t __private; }`.
final class WasmtimeInstance extends Struct {
  @Uint64()
  external int storeId;

  @IntPtr()
  external int privateData;
}

final class WasmConfigOpaque extends Opaque {}

final class WasmEngineOpaque extends Opaque {}

final class WasmtimeModuleOpaque extends Opaque {}

final class WasmtimeStoreOpaque extends Opaque {}

final class WasmtimeContextOpaque extends Opaque {}

final class WasmtimeLinkerOpaque extends Opaque {}

final class WasmtimeErrorOpaque extends Opaque {}

final class WasmTrapOpaque extends Opaque {}

final class WasiConfigOpaque extends Opaque {}

typedef PointerCallbackNative =
    IntPtr Function(Pointer<Void>, Pointer<Uint8>, IntPtr);

typedef ConfigNewNative = Pointer<WasmConfigOpaque> Function();
typedef ConfigDeleteNative = Void Function(Pointer<WasmConfigOpaque>);
typedef ConfigBoolSetNative =
    Void Function(Pointer<WasmConfigOpaque>, Uint8);
typedef ConfigSizeSetNative =
    Void Function(Pointer<WasmConfigOpaque>, IntPtr);
typedef EngineNewNative =
    Pointer<WasmEngineOpaque> Function(Pointer<WasmConfigOpaque>);
typedef EngineDeleteNative = Void Function(Pointer<WasmEngineOpaque>);
typedef EngineIncrementEpochNative =
    Void Function(Pointer<WasmEngineOpaque>);
typedef ModuleNewNative =
    Pointer<WasmtimeErrorOpaque> Function(
      Pointer<WasmEngineOpaque>,
      Pointer<Uint8>,
      IntPtr,
      Pointer<Pointer<WasmtimeModuleOpaque>>,
    );
typedef ModuleDeleteNative = Void Function(Pointer<WasmtimeModuleOpaque>);
typedef StoreNewNative =
    Pointer<WasmtimeStoreOpaque> Function(
      Pointer<WasmEngineOpaque>,
      Pointer<Void>,
      Pointer<Void>,
    );
typedef StoreDeleteNative = Void Function(Pointer<WasmtimeStoreOpaque>);
typedef StoreContextNative =
    Pointer<WasmtimeContextOpaque> Function(Pointer<WasmtimeStoreOpaque>);
typedef StoreLimiterNative =
    Void Function(
      Pointer<WasmtimeStoreOpaque>,
      Int64,
      Int64,
      Int64,
      Int64,
      Int64,
    );
typedef WasiConfigNewNative = Pointer<WasiConfigOpaque> Function();
typedef WasiConfigDeleteNative = Void Function(Pointer<WasiConfigOpaque>);
typedef WasiSetArgvNative =
    Uint8 Function(
      Pointer<WasiConfigOpaque>,
      IntPtr,
      Pointer<Pointer<Utf8>>,
    );
typedef WasiSetCustomNative =
    Void Function(
      Pointer<WasiConfigOpaque>,
      Pointer<NativeFunction<PointerCallbackNative>>,
      Pointer<Void>,
      Pointer<Void>,
    );
typedef WasiSetFileNative =
    Uint8 Function(Pointer<WasiConfigOpaque>, Pointer<Utf8>);
typedef WasiSetFileDart =
    int Function(Pointer<WasiConfigOpaque>, Pointer<Utf8>);
typedef WasiSetStdinBytesNative =
    Void Function(Pointer<WasiConfigOpaque>, Pointer<WasmByteVec>);
typedef WasiSetStdinBytesDart =
    void Function(Pointer<WasiConfigOpaque>, Pointer<WasmByteVec>);
typedef ByteVecNewNative =
    Void Function(Pointer<WasmByteVec>, IntPtr, Pointer<Uint8>);
typedef ByteVecNewDart =
    void Function(Pointer<WasmByteVec>, int, Pointer<Uint8>);
typedef ContextSetWasiNative =
    Pointer<WasmtimeErrorOpaque> Function(
      Pointer<WasmtimeContextOpaque>,
      Pointer<WasiConfigOpaque>,
    );
typedef LinkerNewNative =
    Pointer<WasmtimeLinkerOpaque> Function(Pointer<WasmEngineOpaque>);
typedef LinkerDeleteNative = Void Function(Pointer<WasmtimeLinkerOpaque>);
typedef LinkerDefineWasiNative =
    Pointer<WasmtimeErrorOpaque> Function(Pointer<WasmtimeLinkerOpaque>);
typedef LinkerInstantiateNative =
    Pointer<WasmtimeErrorOpaque> Function(
      Pointer<WasmtimeLinkerOpaque>,
      Pointer<WasmtimeContextOpaque>,
      Pointer<WasmtimeModuleOpaque>,
      Pointer<WasmtimeInstance>,
      Pointer<Pointer<WasmTrapOpaque>>,
    );
typedef InstanceExportGetNative =
    Uint8 Function(
      Pointer<WasmtimeContextOpaque>,
      Pointer<WasmtimeInstance>,
      Pointer<Utf8>,
      IntPtr,
      Pointer<WasmtimeExtern>,
    );
typedef FuncCallNative =
    Pointer<WasmtimeErrorOpaque> Function(
      Pointer<WasmtimeContextOpaque>,
      Pointer<WasmtimeFunc>,
      Pointer<Void>,
      IntPtr,
      Pointer<Void>,
      IntPtr,
      Pointer<Pointer<WasmTrapOpaque>>,
    );
typedef ContextSetEpochDeadlineNative =
    Void Function(Pointer<WasmtimeContextOpaque>, Uint64);
typedef ErrorMessageNative =
    Void Function(Pointer<WasmtimeErrorOpaque>, Pointer<WasmByteVec>);
typedef ErrorExitStatusNative =
    Uint8 Function(Pointer<WasmtimeErrorOpaque>, Pointer<Int32>);
typedef ErrorDeleteNative = Void Function(Pointer<WasmtimeErrorOpaque>);
typedef TrapMessageNative =
    Void Function(Pointer<WasmTrapOpaque>, Pointer<WasmByteVec>);
typedef TrapDeleteNative = Void Function(Pointer<WasmTrapOpaque>);
typedef ByteVecDeleteNative = Void Function(Pointer<WasmByteVec>);

/// Binding tipis ke wasmtime C API (`wasmtime.dll` / `libwasmtime.so`).
final class WasmtimeFfi {
  WasmtimeFfi._(this._library) {
    _bind();
  }

  factory WasmtimeFfi.open({String? path}) {
    return WasmtimeFfi._(DynamicLibrary.open(path ?? resolveLibraryPath()));
  }

  static String resolveLibraryPath() {
    final override = Platform.environment[wasmtimeLibraryEnv];
    if (override != null && override.trim().isNotEmpty) {
      return override;
    }
    if (Platform.isWindows) {
      return 'wasmtime.dll';
    }
    if (Platform.isMacOS) {
      return 'libwasmtime.dylib';
    }
    return 'libwasmtime.so';
  }

  final DynamicLibrary _library;

  late final Pointer<WasmConfigOpaque> Function() configNew;
  late final void Function(Pointer<WasmConfigOpaque>) configDelete;
  late final void Function(Pointer<WasmConfigOpaque>, int)
  configWasmExceptionsSet;
  late final void Function(Pointer<WasmConfigOpaque>, int)
  configEpochInterruptionSet;
  late final void Function(Pointer<WasmConfigOpaque>, int) configMaxWasmStackSet;
  late final Pointer<WasmEngineOpaque> Function(Pointer<WasmConfigOpaque>)
  engineNewWithConfig;
  late final void Function(Pointer<WasmEngineOpaque>) engineDelete;
  late final void Function(Pointer<WasmEngineOpaque>) engineIncrementEpoch;
  late final Pointer<WasmtimeErrorOpaque> Function(
    Pointer<WasmEngineOpaque>,
    Pointer<Uint8>,
    int,
    Pointer<Pointer<WasmtimeModuleOpaque>>,
  )
  moduleNew;
  late final void Function(Pointer<WasmtimeModuleOpaque>) moduleDelete;
  late final Pointer<WasmtimeStoreOpaque> Function(
    Pointer<WasmEngineOpaque>,
    Pointer<Void>,
    Pointer<Void>,
  )
  storeNew;
  late final void Function(Pointer<WasmtimeStoreOpaque>) storeDelete;
  late final Pointer<WasmtimeContextOpaque> Function(Pointer<WasmtimeStoreOpaque>)
  storeContext;
  late final void Function(
    Pointer<WasmtimeStoreOpaque>,
    int,
    int,
    int,
    int,
    int,
  )
  storeLimiter;
  late final Pointer<WasiConfigOpaque> Function() wasiConfigNew;
  late final void Function(Pointer<WasiConfigOpaque>) wasiConfigDelete;
  late final int Function(
    Pointer<WasiConfigOpaque>,
    int,
    Pointer<Pointer<Utf8>>,
  )
  wasiConfigSetArgv;
  late final void Function(
    Pointer<WasiConfigOpaque>,
    Pointer<NativeFunction<PointerCallbackNative>>,
    Pointer<Void>,
    Pointer<Void>,
  )
  wasiConfigSetStdoutCustom;
  late final void Function(
    Pointer<WasiConfigOpaque>,
    Pointer<NativeFunction<PointerCallbackNative>>,
    Pointer<Void>,
    Pointer<Void>,
  )
  wasiConfigSetStderrCustom;
  late final int Function(Pointer<WasiConfigOpaque>, Pointer<Utf8>)
  wasiConfigSetStdoutFile;
  late final int Function(Pointer<WasiConfigOpaque>, Pointer<Utf8>)
  wasiConfigSetStderrFile;
  late final void Function(Pointer<WasiConfigOpaque>, Pointer<WasmByteVec>)
  wasiConfigSetStdinBytes;
  late final Pointer<WasmtimeErrorOpaque> Function(
    Pointer<WasmtimeContextOpaque>,
    Pointer<WasiConfigOpaque>,
  )
  contextSetWasi;
  late final Pointer<WasmtimeLinkerOpaque> Function(Pointer<WasmEngineOpaque>)
  linkerNew;
  late final void Function(Pointer<WasmtimeLinkerOpaque>) linkerDelete;
  late final Pointer<WasmtimeErrorOpaque> Function(
    Pointer<WasmtimeLinkerOpaque>,
  )
  linkerDefineWasi;
  late final Pointer<WasmtimeErrorOpaque> Function(
    Pointer<WasmtimeLinkerOpaque>,
    Pointer<WasmtimeContextOpaque>,
    Pointer<WasmtimeModuleOpaque>,
    Pointer<WasmtimeInstance>,
    Pointer<Pointer<WasmTrapOpaque>>,
  )
  linkerInstantiate;
  late final int Function(
    Pointer<WasmtimeContextOpaque>,
    Pointer<WasmtimeInstance>,
    Pointer<Utf8>,
    int,
    Pointer<WasmtimeExtern>,
  )
  instanceExportGet;
  late final Pointer<WasmtimeErrorOpaque> Function(
    Pointer<WasmtimeContextOpaque>,
    Pointer<WasmtimeFunc>,
    Pointer<Void>,
    int,
    Pointer<Void>,
    int,
    Pointer<Pointer<WasmTrapOpaque>>,
  )
  funcCall;
  late final void Function(Pointer<WasmtimeContextOpaque>, int)
  contextSetEpochDeadline;
  late final void Function(Pointer<WasmtimeErrorOpaque>, Pointer<WasmByteVec>)
  errorMessage;
  late final int Function(Pointer<WasmtimeErrorOpaque>, Pointer<Int32>)
  errorExitStatus;
  late final void Function(Pointer<WasmtimeErrorOpaque>) errorDelete;
  late final void Function(Pointer<WasmTrapOpaque>, Pointer<WasmByteVec>)
  trapMessage;
  late final void Function(Pointer<WasmTrapOpaque>) trapDelete;
  late final void Function(Pointer<WasmByteVec>, int, Pointer<Uint8>)
  byteVecNew;
  late final void Function(Pointer<WasmByteVec>) byteVecDelete;

  void _bind() {
    configNew = _library.lookupFunction<ConfigNewNative, ConfigNewDart>(
      'wasm_config_new',
    );
    configDelete = _library.lookupFunction<
      ConfigDeleteNative,
      ConfigDeleteDart
    >('wasm_config_delete');
    configWasmExceptionsSet = _library.lookupFunction<
      ConfigBoolSetNative,
      ConfigBoolSetDart
    >('wasmtime_config_wasm_exceptions_set');
    configEpochInterruptionSet = _library.lookupFunction<
      ConfigBoolSetNative,
      ConfigBoolSetDart
    >('wasmtime_config_epoch_interruption_set');
    configMaxWasmStackSet = _library.lookupFunction<
      ConfigSizeSetNative,
      ConfigSizeSetDart
    >('wasmtime_config_max_wasm_stack_set');
    engineNewWithConfig = _library.lookupFunction<
      EngineNewNative,
      EngineNewDart
    >('wasm_engine_new_with_config');
    engineDelete = _library.lookupFunction<EngineDeleteNative, EngineDeleteDart>(
      'wasm_engine_delete',
    );
    engineIncrementEpoch = _library.lookupFunction<
      EngineIncrementEpochNative,
      EngineIncrementEpochDart
    >('wasmtime_engine_increment_epoch');
    moduleNew = _library.lookupFunction<ModuleNewNative, ModuleNewDart>(
      'wasmtime_module_new',
    );
    moduleDelete = _library.lookupFunction<ModuleDeleteNative, ModuleDeleteDart>(
      'wasmtime_module_delete',
    );
    storeNew = _library.lookupFunction<StoreNewNative, StoreNewDart>(
      'wasmtime_store_new',
    );
    storeDelete = _library.lookupFunction<StoreDeleteNative, StoreDeleteDart>(
      'wasmtime_store_delete',
    );
    storeContext = _library.lookupFunction<StoreContextNative, StoreContextDart>(
      'wasmtime_store_context',
    );
    storeLimiter = _library.lookupFunction<StoreLimiterNative, StoreLimiterDart>(
      'wasmtime_store_limiter',
    );
    wasiConfigNew = _library.lookupFunction<WasiConfigNewNative, WasiConfigNewDart>(
      'wasi_config_new',
    );
    wasiConfigDelete = _library.lookupFunction<
      WasiConfigDeleteNative,
      WasiConfigDeleteDart
    >('wasi_config_delete');
    wasiConfigSetArgv = _library.lookupFunction<
      WasiSetArgvNative,
      WasiSetArgvDart
    >('wasi_config_set_argv');
    wasiConfigSetStdoutCustom = _library.lookupFunction<
      WasiSetCustomNative,
      WasiSetCustomDart
    >('wasi_config_set_stdout_custom');
    wasiConfigSetStderrCustom = _library.lookupFunction<
      WasiSetCustomNative,
      WasiSetCustomDart
    >('wasi_config_set_stderr_custom');
    wasiConfigSetStdoutFile = _library.lookupFunction<
      WasiSetFileNative,
      WasiSetFileDart
    >('wasi_config_set_stdout_file');
    wasiConfigSetStderrFile = _library.lookupFunction<
      WasiSetFileNative,
      WasiSetFileDart
    >('wasi_config_set_stderr_file');
    wasiConfigSetStdinBytes = _library.lookupFunction<
      WasiSetStdinBytesNative,
      WasiSetStdinBytesDart
    >('wasi_config_set_stdin_bytes');
    contextSetWasi = _library.lookupFunction<
      ContextSetWasiNative,
      ContextSetWasiDart
    >('wasmtime_context_set_wasi');
    linkerNew = _library.lookupFunction<LinkerNewNative, LinkerNewDart>(
      'wasmtime_linker_new',
    );
    linkerDelete = _library.lookupFunction<LinkerDeleteNative, LinkerDeleteDart>(
      'wasmtime_linker_delete',
    );
    linkerDefineWasi = _library.lookupFunction<
      LinkerDefineWasiNative,
      LinkerDefineWasiDart
    >('wasmtime_linker_define_wasi');
    linkerInstantiate = _library.lookupFunction<
      LinkerInstantiateNative,
      LinkerInstantiateDart
    >('wasmtime_linker_instantiate');
    instanceExportGet = _library.lookupFunction<
      InstanceExportGetNative,
      InstanceExportGetDart
    >('wasmtime_instance_export_get');
    funcCall = _library.lookupFunction<FuncCallNative, FuncCallDart>(
      'wasmtime_func_call',
    );
    contextSetEpochDeadline = _library.lookupFunction<
      ContextSetEpochDeadlineNative,
      ContextSetEpochDeadlineDart
    >('wasmtime_context_set_epoch_deadline');
    errorMessage = _library.lookupFunction<ErrorMessageNative, ErrorMessageDart>(
      'wasmtime_error_message',
    );
    errorExitStatus = _library.lookupFunction<
      ErrorExitStatusNative,
      ErrorExitStatusDart
    >('wasmtime_error_exit_status');
    errorDelete = _library.lookupFunction<ErrorDeleteNative, ErrorDeleteDart>(
      'wasmtime_error_delete',
    );
    trapMessage = _library.lookupFunction<TrapMessageNative, TrapMessageDart>(
      'wasm_trap_message',
    );
    trapDelete = _library.lookupFunction<TrapDeleteNative, TrapDeleteDart>(
      'wasm_trap_delete',
    );
    byteVecNew = _library.lookupFunction<ByteVecNewNative, ByteVecNewDart>(
      'wasm_byte_vec_new',
    );
    byteVecDelete = _library.lookupFunction<
      ByteVecDeleteNative,
      ByteVecDeleteDart
    >('wasm_byte_vec_delete');
  }
}

typedef ConfigNewDart = Pointer<WasmConfigOpaque> Function();
typedef ConfigDeleteDart = void Function(Pointer<WasmConfigOpaque>);
typedef ConfigBoolSetDart = void Function(Pointer<WasmConfigOpaque>, int);
typedef ConfigSizeSetDart = void Function(Pointer<WasmConfigOpaque>, int);
typedef EngineNewDart =
    Pointer<WasmEngineOpaque> Function(Pointer<WasmConfigOpaque>);
typedef EngineDeleteDart = void Function(Pointer<WasmEngineOpaque>);
typedef EngineIncrementEpochDart = void Function(Pointer<WasmEngineOpaque>);
typedef ModuleNewDart =
    Pointer<WasmtimeErrorOpaque> Function(
      Pointer<WasmEngineOpaque>,
      Pointer<Uint8>,
      int,
      Pointer<Pointer<WasmtimeModuleOpaque>>,
    );
typedef ModuleDeleteDart = void Function(Pointer<WasmtimeModuleOpaque>);
typedef StoreNewDart =
    Pointer<WasmtimeStoreOpaque> Function(
      Pointer<WasmEngineOpaque>,
      Pointer<Void>,
      Pointer<Void>,
    );
typedef StoreDeleteDart = void Function(Pointer<WasmtimeStoreOpaque>);
typedef StoreContextDart =
    Pointer<WasmtimeContextOpaque> Function(Pointer<WasmtimeStoreOpaque>);
typedef StoreLimiterDart =
    void Function(
      Pointer<WasmtimeStoreOpaque>,
      int,
      int,
      int,
      int,
      int,
    );
typedef WasiConfigNewDart = Pointer<WasiConfigOpaque> Function();
typedef WasiConfigDeleteDart = void Function(Pointer<WasiConfigOpaque>);
typedef WasiSetArgvDart =
    int Function(Pointer<WasiConfigOpaque>, int, Pointer<Pointer<Utf8>>);
typedef WasiSetCustomDart =
    void Function(
      Pointer<WasiConfigOpaque>,
      Pointer<NativeFunction<PointerCallbackNative>>,
      Pointer<Void>,
      Pointer<Void>,
    );
typedef ContextSetWasiDart =
    Pointer<WasmtimeErrorOpaque> Function(
      Pointer<WasmtimeContextOpaque>,
      Pointer<WasiConfigOpaque>,
    );
typedef LinkerNewDart =
    Pointer<WasmtimeLinkerOpaque> Function(Pointer<WasmEngineOpaque>);
typedef LinkerDeleteDart = void Function(Pointer<WasmtimeLinkerOpaque>);
typedef LinkerDefineWasiDart =
    Pointer<WasmtimeErrorOpaque> Function(Pointer<WasmtimeLinkerOpaque>);
typedef LinkerInstantiateDart =
    Pointer<WasmtimeErrorOpaque> Function(
      Pointer<WasmtimeLinkerOpaque>,
      Pointer<WasmtimeContextOpaque>,
      Pointer<WasmtimeModuleOpaque>,
      Pointer<WasmtimeInstance>,
      Pointer<Pointer<WasmTrapOpaque>>,
    );
typedef InstanceExportGetDart =
    int Function(
      Pointer<WasmtimeContextOpaque>,
      Pointer<WasmtimeInstance>,
      Pointer<Utf8>,
      int,
      Pointer<WasmtimeExtern>,
    );
typedef FuncCallDart =
    Pointer<WasmtimeErrorOpaque> Function(
      Pointer<WasmtimeContextOpaque>,
      Pointer<WasmtimeFunc>,
      Pointer<Void>,
      int,
      Pointer<Void>,
      int,
      Pointer<Pointer<WasmTrapOpaque>>,
    );
typedef ContextSetEpochDeadlineDart =
    void Function(Pointer<WasmtimeContextOpaque>, int);
typedef ErrorMessageDart =
    void Function(Pointer<WasmtimeErrorOpaque>, Pointer<WasmByteVec>);
typedef ErrorExitStatusDart = int Function(Pointer<WasmtimeErrorOpaque>, Pointer<Int32>);
typedef ErrorDeleteDart = void Function(Pointer<WasmtimeErrorOpaque>);
typedef TrapMessageDart = void Function(Pointer<WasmTrapOpaque>, Pointer<WasmByteVec>);
typedef TrapDeleteDart = void Function(Pointer<WasmTrapOpaque>);
typedef ByteVecDeleteDart = void Function(Pointer<WasmByteVec>);
