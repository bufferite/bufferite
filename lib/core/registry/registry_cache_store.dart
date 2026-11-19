import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'registry_cache.dart';
import 'registry_error.dart';

/// Cache registry di `<application support>/registry/registry_cache.json`.
final class FileRegistryCacheStore implements RegistryCacheStore {
  FileRegistryCacheStore({
    Future<Directory> Function()? directory,
    this.fileName = 'registry_cache.json',
  }) : _directory = directory ?? _defaultDirectory;

  final Future<Directory> Function() _directory;
  final String fileName;

  static Future<Directory> _defaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}${Platform.pathSeparator}registry');
  }

  Future<File> _file() async {
    final directory = await _directory();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<RegistryCache?> read() async {
    final file = await _file();
    if (!file.existsSync()) {
      return null;
    }
    try {
      if (file.lengthSync() > registryMaxCacheBytes) {
        throw const RegistryClientException(
          'registry.cache_corrupt',
          'Cache registry melebihi batas ukuran.',
        );
      }
      return RegistryCache.fromBytes(await file.readAsBytes());
    } on RegistryClientException {
      rethrow;
    } on FileSystemException catch (error) {
      throw RegistryClientException(
        'registry.cache_corrupt',
        'Cache registry tidak dapat dibaca: ${error.message}',
      );
    }
  }

  @override
  Future<void> write(RegistryCache cache) async {
    final file = await _file();
    try {
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.tmp');
      await temp.writeAsBytes(cache.encode(), flush: true);
      if (file.existsSync()) {
        await file.delete();
      }
      await temp.rename(file.path);
    } on FileSystemException catch (error) {
      throw RegistryClientException(
        'registry.cache_io',
        'Cache registry tidak dapat ditulis: ${error.message}',
      );
    }
  }

  @override
  Future<void> clear() async {
    final file = await _file();
    try {
      if (file.existsSync()) {
        await file.delete();
      }
      final temp = File('${file.path}.tmp');
      if (temp.existsSync()) {
        await temp.delete();
      }
    } on FileSystemException catch (error) {
      throw RegistryClientException(
        'registry.cache_io',
        'Cache registry tidak dapat dihapus: ${error.message}',
      );
    }
  }
}
