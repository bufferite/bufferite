import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

Map<String, Object?> validManifestJson({
  String pluginId = 'com.test.pack',
  String version = '1.0.0',
  String tier = 'lua',
  String entrypoint = 'main.lua',
  String operationId = 'test.operation',
}) {
  return <String, Object?>{
    'manifestVersion': 1,
    'pluginId': pluginId,
    'name': 'Test Pack',
    'version': version,
    'minAppVersion': '1.0.0',
    'tier': tier,
    'entrypoint': entrypoint,
    'permissions': <Object?>['cpu'],
    'operations': <Object?>[
      <String, Object?>{
        'id': operationId,
        'name': 'Test Operation',
        'category': 'Utility',
        'params': <Object?>[],
        'inputType': 'text',
        'outputType': 'text',
      },
    ],
  };
}

Uint8List buildPackageZip({
  Map<String, Object?>? manifest,
  Map<String, String> files = const <String, String>{
    'main.lua': 'return function(input, args) return input end',
  },
  List<ArchiveFile> extraFiles = const <ArchiveFile>[],
}) {
  final archive = Archive()
    ..addFile(
      ArchiveFile.string(
        'plugin.manifest.json',
        jsonEncode(manifest ?? validManifestJson()),
      ),
    );
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile.string(entry.key, entry.value));
  }
  for (final entry in extraFiles) {
    archive.addFile(entry);
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
