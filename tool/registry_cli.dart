import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/plugin_package.dart';
import 'package:bufferite/core/plugin/plugin_permission.dart';
import 'package:bufferite/core/registry/registry_index.dart';
import 'package:bufferite/core/registry/registry_signature.dart';
import 'package:crypto/crypto.dart';

import 'registry/registry_builder.dart';

/// Entry point CLI registry.
///
/// Jalankan: `dart run tool/registry_cli.dart <perintah> [opsi]`.
Future<void> main(List<String> args) async {
  final code = await runRegistryCli(args, out: stdout, err: stderr);
  if (code != 0) {
    exitCode = code;
  }
}

/// Versi testable dari CLI; mengembalikan exit code.
Future<int> runRegistryCli(
  List<String> args, {
  required StringSink out,
  required StringSink err,
}) async {
  if (args.isEmpty || args.first == 'help' || args.first == '--help') {
    out.writeln(_usage);
    return args.isEmpty ? 1 : 0;
  }

  final command = args.first;
  final spec = _commandSpecs[command];
  if (spec == null) {
    err.writeln('Perintah tidak dikenal: $command');
    err.writeln(_usage);
    return 2;
  }
  final parsed = _Args.parse(args.skip(1).toList());
  final unknownOptions =
      parsed.options.keys.where((name) => !spec.options.contains(name)).toList()
        ..sort();
  if (unknownOptions.isNotEmpty) {
    err.writeln('Opsi tidak dikenal: ${unknownOptions.join(', ')}');
    return 2;
  }
  if (parsed.positional.length != spec.positionals) {
    err.writeln('Argumen posisi untuk $command tidak sesuai.');
    err.writeln(_usage);
    return 2;
  }

  try {
    switch (command) {
      case 'keygen':
        return await _keygen(parsed, out);
      case 'validate':
        return await _validate(parsed, out);
      case 'sign':
        return await _sign(parsed, out);
      case 'build-index':
        return await _buildIndex(parsed, out);
      case 'verify':
        return await _verify(parsed, out);
      default:
        err.writeln('Perintah tidak dikenal: $command');
        err.writeln(_usage);
        return 2;
    }
  } on RegistryFormatException catch (error) {
    err.writeln('error ${error.code}: ${error.message}');
    return 1;
  } on AppError catch (error) {
    err.writeln('error ${error.code}: ${error.message}');
    return 1;
  } on FileSystemException catch (error) {
    err.writeln('error file: ${error.message} (${error.path ?? '-'})');
    return 1;
  } on FormatException catch (error) {
    err.writeln('error format: ${error.message}');
    return 1;
  }
}

Future<int> _keygen(_Args args, StringSink out) async {
  final keyId = args.required('--key-id');
  final target = File(args.required('--out'));
  final usage = args.optional('--usage') ?? 'both';
  if (usage != 'index' && usage != 'package' && usage != 'both') {
    throw const RegistryFormatException(
      'registry.key_invalid',
      '--usage harus index, package, atau both.',
    );
  }
  if (target.existsSync() && !args.flag('--force')) {
    throw RegistryFormatException(
      'registry.key_invalid',
      'File ${target.path} sudah ada; pakai --force untuk menimpa.',
    );
  }
  final publicOut = args.optional('--public-out');
  final publicFile = publicOut == null ? null : File(publicOut);
  if (publicFile != null && publicFile.existsSync() && !args.flag('--force')) {
    throw RegistryFormatException(
      'registry.key_invalid',
      'File ${publicFile.path} sudah ada; pakai --force untuk menimpa.',
    );
  }

  final generated = await generateRegistryKey(keyId: keyId);
  writeFileAtomically(target, generated.privateKey.encode());
  out.writeln('Private key ditulis: ${target.path}');
  out.writeln('keyId: $keyId');
  out.writeln('publicKey: ${base64Encode(generated.publicKey)}');

  if (publicFile != null) {
    final trustStore = <String, Object?>{
      'keys': <Object?>[
        <String, Object?>{
          'keyId': keyId,
          'algorithm': 'ed25519',
          'usage': usage,
          'publicKey': base64Encode(generated.publicKey),
          'status': 'active',
          'createdAt': _today(),
        },
      ],
    };
    writeFileAtomically(
      publicFile,
      '${const JsonEncoder.withIndent('  ').convert(trustStore)}\n',
    );
    out.writeln('Trust store ditulis: ${publicFile.path}');
  }
  out.writeln(
    usage == 'index'
        ? 'Kunci indeks wajib disimpan offline/air-gapped (D13).'
        : 'Simpan private key sebagai secret CI; hanya kunci indeks yang offline (D13).',
  );
  return 0;
}

Future<int> _sign(_Args args, StringSink out) async {
  final target = args.positional.first;
  if (target != 'index' && target != 'package') {
    throw const RegistryFormatException(
      'registry.signature_invalid',
      'sign membutuhkan target index atau package.',
    );
  }
  final input = File(args.required('--in'));
  final output = File(args.required('--out'));
  final key = RegistryPrivateKey.fromBytes(
    _readFile(File(args.required('--key')), 64 * 1024, 'file kunci'),
  );
  final bytes = _readFile(
    input,
    target == 'index' ? registryMaxIndexBytes : 32 * 1024 * 1024,
    'file input',
  );

  final RegistrySignature signature;
  if (target == 'index') {
    signature = await signRegistryIndex(key: key, bytes: bytes);
  } else {
    final package = PluginPackage.decode(bytes);
    signature = await signRegistryPackage(
      key: key,
      pluginId: package.manifest.pluginId,
      version: package.manifest.version.toString(),
      bytes: bytes,
    );
  }
  writeFileAtomically(output, signature.encode());
  out.writeln('Signature ditulis: ${output.path}');
  out.writeln('keyId: ${signature.keyId}');
  out.writeln('sha256: ${sha256.convert(bytes)}');
  return 0;
}

Future<int> _buildIndex(_Args args, StringSink out) async {
  final source = File(args.required('--source'));
  final output = File(args.required('--out'));
  final base = args.optional('--base');
  final keyring = args.optional('--keyring');
  final sequenceText = args.optional('--sequence');
  final sequence = sequenceText == null ? null : int.tryParse(sequenceText);
  if (sequenceText != null && (sequence == null || sequence < 1)) {
    throw const RegistryFormatException(
      'registry.schema',
      '--sequence harus integer positif.',
    );
  }
  final generatedText = args.optional('--generated-at');
  final generatedAt = generatedText == null
      ? null
      : _date(generatedText, '--generated-at');
  final trustStore = keyring == null
      ? null
      : RegistryTrustStore.fromBytes(
          _readFile(File(keyring), 64 * 1024, 'keyring'),
        );

  final result = await const RegistryIndexBuilder().build(
    sourceFile: source,
    baseIndexFile: base == null ? null : File(base),
    sequence: sequence,
    generatedAt: generatedAt,
    trustStore: trustStore,
  );
  writeFileAtomically(output, result.content);
  out.writeln('registry.json ditulis: ${output.path}');
  out.writeln('sequence: ${result.index.sequence}');
  out.writeln('entries: ${result.index.plugins.length}');
  out.writeln('sha256: ${sha256.convert(utf8.encode(result.content))}');
  out.writeln(
    'Langkah berikutnya: sign index, lalu publikasikan indeks '
    'terakhir.',
  );
  return 0;
}

Future<int> _validate(_Args args, StringSink out) async {
  final target = args.positional.first;
  if (target == 'package') {
    final signature = args.optional('--sig');
    final keyring = args.optional('--keyring');
    return _validatePackage(
      File(args.required('--in')),
      signature == null ? null : File(signature),
      keyring == null ? null : File(keyring),
      out,
    );
  }
  if (target == 'index') {
    final bytes = _readFile(
      File(args.required('--in')),
      registryMaxIndexBytes,
      'registry.json',
    );
    final index = RegistryIndex.fromBytes(bytes);
    final baseUrl = args.optional('--base-url');
    if (baseUrl != null) {
      index.validateUrls(_baseUri(baseUrl));
    } else {
      out.writeln(
        'warning: --base-url tidak diberikan; URL paket tidak divalidasi.',
      );
    }
    out.writeln('registry.json valid');
    out.writeln('sequence: ${index.sequence}');
    out.writeln('generatedAt: ${index.generatedAt.toIso8601String()}');
    out.writeln('entries: ${index.plugins.length}');
    out.writeln('allowedHosts: ${index.allowedHosts.join(', ')}');
    return 0;
  }
  throw const RegistryFormatException(
    'registry.schema',
    'validate membutuhkan target package atau index.',
  );
}

Future<int> _validatePackage(
  File input,
  File? signatureFile,
  File? keyringFile,
  StringSink out,
) async {
  final bytes = _readFile(input, 32 * 1024 * 1024, 'paket');
  final package = PluginPackage.decode(bytes);
  final manifest = package.manifest;
  final digest = sha256.convert(bytes).toString();
  final warnings = <String>[];

  if (manifest.license == null) {
    warnings.add('license tidak dicantumkan.');
  }
  if (manifest.permissions.contains(PluginPermission.net)) {
    warnings.add('meminta izin net; review tujuan jaringan.');
  }
  if (manifest.permissions.contains(PluginPermission.fileRead) ||
      manifest.permissions.contains(PluginPermission.fileWrite)) {
    warnings.add('meminta izin file; review jalur dan tujuan.');
  }
  final entrypoint = package.entrypointBytes();
  if (manifest.integritySha256 != null) {
    final actual = sha256.convert(entrypoint).toString();
    if (actual != manifest.integritySha256) {
      throw RegistryFormatException(
        'registry.entry_invalid',
        'integrity.sha256 manifest tidak cocok dengan entrypoint '
            '($actual).',
      );
    }
  }
  if (manifest.tier == RuntimeTier.lua) {
    try {
      final source = utf8.decode(entrypoint);
      if (source.contains('\u0000')) {
        warnings.add('entrypoint Lua memuat NUL; periksa obfuscation.');
      }
    } on FormatException {
      warnings.add('entrypoint Lua bukan UTF-8 valid; periksa obfuscation.');
    }
  }

  if (signatureFile != null || keyringFile != null) {
    if (signatureFile == null || keyringFile == null) {
      throw const RegistryFormatException(
        'registry.signature_invalid',
        '--sig dan --keyring harus dipakai bersama.',
      );
    }
    final signature = RegistrySignature.fromBytes(
      _readFile(signatureFile, registryMaxSignatureBytes, 'signature'),
    );
    final trustStore = RegistryTrustStore.fromBytes(
      _readFile(keyringFile, 64 * 1024, 'keyring'),
    );
    await verifyRegistrySignature(
      signature: signature,
      message: registryPackageMessage(
        pluginId: manifest.pluginId,
        version: manifest.version.toString(),
        bytes: bytes,
      ),
      trustStore: trustStore,
      usage: 'package',
    );
    out.writeln('signature valid (${signature.keyId})');
  }

  out.writeln('paket valid');
  out.writeln('pluginId: ${manifest.pluginId}');
  out.writeln('version: ${manifest.version}');
  out.writeln('tier: ${manifest.tier.name}');
  out.writeln('name: ${manifest.name}');
  out.writeln('sizeBytes: ${bytes.length}');
  out.writeln('sha256: $digest');
  out.writeln('files: ${package.fileNames.length}');
  out.writeln(
    'permissions: ${manifest.permissions.map((item) => item.wireName).join(', ')}',
  );
  out.writeln('operations: ${manifest.operations.length}');
  for (final warning in warnings) {
    out.writeln('warning: $warning');
  }
  return 0;
}

Future<int> _verify(_Args args, StringSink out) async {
  final target = args.positional.first;
  if (target != 'index' && target != 'package') {
    throw const RegistryFormatException(
      'registry.signature_invalid',
      'verify membutuhkan target index atau package.',
    );
  }
  final bytes = _readFile(
    File(args.required('--in')),
    target == 'index' ? registryMaxIndexBytes : 32 * 1024 * 1024,
    'file input',
  );
  final signature = RegistrySignature.fromBytes(
    _readFile(
      File(args.required('--sig')),
      registryMaxSignatureBytes,
      'signature',
    ),
  );
  final trustStore = RegistryTrustStore.fromBytes(
    _readFile(File(args.required('--keyring')), 64 * 1024, 'keyring'),
  );

  final String message;
  if (target == 'index') {
    message = registryIndexMessage(bytes);
  } else {
    final package = PluginPackage.decode(bytes);
    final pluginId = args.optional('--plugin-id') ?? package.manifest.pluginId;
    final version =
        args.optional('--version') ?? package.manifest.version.toString();
    if (pluginId != package.manifest.pluginId ||
        version != package.manifest.version.toString()) {
      throw const RegistryFormatException(
        'registry.signature_invalid',
        '--plugin-id/--version tidak cocok dengan manifest paket.',
      );
    }
    message = registryPackageMessage(
      pluginId: pluginId,
      version: version,
      bytes: bytes,
    );
  }

  await verifyRegistrySignature(
    signature: signature,
    message: message,
    trustStore: trustStore,
    usage: target == 'index' ? 'index' : 'package',
  );
  out.writeln('signature valid');
  out.writeln('keyId: ${signature.keyId}');
  out.writeln('sha256: ${sha256.convert(bytes)}');
  if (target == 'index') {
    final index = RegistryIndex.fromBytes(bytes);
    out.writeln('sequence: ${index.sequence}');
    out.writeln('entries: ${index.plugins.length}');
    final baseUrl = args.optional('--base-url');
    if (baseUrl != null) {
      index.validateUrls(_baseUri(baseUrl));
      out.writeln('URL paket valid terhadap allowedHosts');
    } else {
      out.writeln(
        'warning: --base-url tidak diberikan; URL paket tidak divalidasi.',
      );
    }
  }
  return 0;
}

Uint8List _readFile(File file, int maxBytes, String label) {
  if (!file.existsSync()) {
    throw RegistryFormatException(
      'registry.io',
      '$label tidak ditemukan: ${file.path}',
    );
  }
  final length = file.lengthSync();
  if (length > maxBytes) {
    throw RegistryFormatException(
      'registry.too_large',
      '$label melebihi $maxBytes byte: ${file.path}',
    );
  }
  return file.readAsBytesSync();
}

Uri _baseUri(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw const RegistryFormatException(
      'registry.schema',
      '--base-url harus URL HTTPS.',
    );
  }
  return uri;
}

DateTime _date(String value, String field) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw RegistryFormatException(
      'registry.schema',
      '$field harus ISO-8601 UTC.',
    );
  }
  return parsed;
}

String _today() {
  final now = DateTime.now().toUtc();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

final class _CommandSpec {
  const _CommandSpec({required this.positionals, required this.options});

  final int positionals;
  final Set<String> options;
}

const Map<String, _CommandSpec> _commandSpecs = <String, _CommandSpec>{
  'keygen': _CommandSpec(
    positionals: 0,
    options: <String>{
      '--key-id',
      '--out',
      '--public-out',
      '--usage',
      '--force',
    },
  ),
  'validate': _CommandSpec(
    positionals: 1,
    options: <String>{'--in', '--sig', '--keyring', '--base-url'},
  ),
  'sign': _CommandSpec(
    positionals: 1,
    options: <String>{'--in', '--out', '--key'},
  ),
  'build-index': _CommandSpec(
    positionals: 0,
    options: <String>{
      '--source',
      '--out',
      '--base',
      '--sequence',
      '--generated-at',
      '--keyring',
    },
  ),
  'verify': _CommandSpec(
    positionals: 1,
    options: <String>{
      '--in',
      '--sig',
      '--keyring',
      '--plugin-id',
      '--version',
      '--base-url',
    },
  ),
};

final class _Args {
  const _Args(this.options, this.positional);

  final Map<String, String?> options;
  final List<String> positional;

  factory _Args.parse(List<String> args) {
    final options = <String, String?>{};
    final positional = <String>[];
    for (var index = 0; index < args.length; index++) {
      final arg = args[index];
      if (!arg.startsWith('--')) {
        positional.add(arg);
        continue;
      }
      final equals = arg.indexOf('=');
      if (equals != -1) {
        options[arg.substring(0, equals)] = arg.substring(equals + 1);
        continue;
      }
      final next = index + 1 < args.length ? args[index + 1] : null;
      if (next != null && !next.startsWith('--')) {
        options[arg] = next;
        index++;
      } else {
        options[arg] = null;
      }
    }
    return _Args(options, positional);
  }

  String required(String name) {
    final value = options[name];
    if (value == null || value.isEmpty) {
      throw RegistryFormatException(
        'registry.schema',
        'Opsi $name wajib diisi.',
      );
    }
    return value;
  }

  String? optional(String name) => options[name];

  bool flag(String name) => options.containsKey(name);
}

const String _usage = '''
Bufferite registry tooling

Perintah:
  keygen       --key-id <id> --out <key.json> [--public-out <keys.json>]
               [--usage index|package|both] [--force]
  validate package --in <paket.berp> [--sig <paket.berp.sig> --keyring <keys.json>]
  validate index   --in <registry.json> [--base-url <https://.../registry.json>]
  sign index       --in <registry.json> --out <registry.json.sig> --key <key.json>
  sign package     --in <paket.berp> --out <paket.berp.sig> --key <key.json>
  build-index      --source <registry-source.json> --out <registry.json>
                   [--base <registry-lama.json>] [--sequence <n>]
                   [--generated-at <ISO-8601>] [--keyring <keys.json>]
  verify index     --in <registry.json> --sig <registry.json.sig>
                   --keyring <keys.json> [--base-url <https://.../registry.json>]
  verify package   --in <paket.berp> --sig <paket.berp.sig>
                   --keyring <keys.json> [--plugin-id <id> --version <semver>]
''';
