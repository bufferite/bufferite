import 'dart:io';

import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/engine/pipeline_executor.dart';
import 'package:bufferite/core/operations/encode_decode.dart';
import 'package:bufferite/core/plugin/installed_plugin.dart';
import 'package:bufferite/core/plugin/manifest_registrar.dart';
import 'package:bufferite/core/plugin/operation.dart';
import 'package:bufferite/core/plugin/operation_param.dart';
import 'package:bufferite/core/plugin/operation_registry.dart';
import 'package:bufferite/core/plugin/plugin_package.dart';
import 'package:bufferite/core/plugin/plugin_package_store.dart';
import 'package:bufferite/core/storage/app_database.dart';
import 'package:bufferite/features/plugins/plugin_repository.dart';
import 'package:bufferite/features/recipe/recipe.dart';
import 'package:bufferite/features/recipe/recipe_codec.dart';
import 'package:bufferite/features/recipe/recipe_pipeline.dart';
import 'package:bufferite/features/recipe/recipe_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/plugin_fixtures.dart';

void main() {
  sqfliteFfiInit();

  late Directory temp;
  late AppDatabase database;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('bufferite_e2e_');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${temp.path}/bufferite.db',
    );
  });

  tearDown(() async {
    await database.close();
    if (temp.existsSync()) {
      await temp.delete(recursive: true);
    }
  });

  test(
    'bootstrap -> sideload -> recipe -> simpan -> ekspor/impor -> run',
    () async {
      // 1. Sideload plugin dari paket.
      final package = PluginPackage.decode(buildPackageZip());
      final store = PluginPackageStore(Directory('${temp.path}/plugins'));
      final installPath = await store.install(package);

      final plugins = PluginRepository(database);
      await plugins.save(
        InstalledPlugin(
          manifest: package.manifest,
          source: PluginSource.sideload,
          installedAt: DateTime.utc(2026, 1, 1),
          verified: false,
          installPath: installPath,
        ),
      );
      expect((await plugins.list()).single.pluginId, 'com.test.pack');

      // 2. Registry berisi operasi core encode/decode.
      final registry = OperationRegistry();
      for (final Operation op in <Operation>[
        const Base64EncodeOperation(),
        const Base64DecodeOperation(),
      ]) {
        registry.registerOperation(
          op,
          pluginId: 'dev.bufferite.core',
          pluginVersion: '1.0.0',
          tier: RuntimeTier.dsl,
        );
      }
      // Registrasi operasi plugin sideload dengan executor dummy.
      ManifestRegistrar(
        registry,
      ).register(package.manifest, executorFor: (id) => _IdentityOperation(id));

      // 3. Buat recipe multi-step dan jalankan.
      final recipe = Recipe(
        id: '11111111-1111-4111-8111-111111111111',
        name: 'Roundtrip',
        steps: <RecipeStep>[
          RecipeStep(id: 's1', operationId: 'core.base64_encode'),
          RecipeStep(id: 's2', operationId: 'core.base64_decode'),
        ],
        input: const TextBuffer('halo'),
      );
      final executor = PipelineExecutor(registry: registry);
      final run = await executor.execute(
        steps: recipe.toPipelineSteps(),
        input: recipe.input,
      );
      expect(run.output.asText(), 'halo');

      // 4. Simpan ke storage lalu buka lagi.
      final recipes = RecipeRepository(database);
      await recipes.save(recipe);
      expect((await recipes.byId(recipe.id))!.name, 'Roundtrip');

      // 5. Ekspor .brecipe lalu impor kembali.
      final codec = RecipeCodec();
      final encoded = codec.encode(recipe);
      expect(encoded.isSuccess, isTrue);
      final decoded = codec.decode(encoded.valueOrNull!);
      expect(decoded.isSuccess, isTrue);
      expect(decoded.valueOrNull!.steps, hasLength(2));
    },
  );
}

final class _IdentityOperation implements Operation {
  _IdentityOperation(this._id);
  final String _id;
  @override
  String get id => _id;
  @override
  String get name => 'Identity';
  @override
  OperationCategory get category => OperationCategory.utility;
  @override
  List<OperationParam> get params => const <OperationParam>[];
  @override
  OperationIO get io =>
      const OperationIO(input: BufferKind.text, output: BufferKind.text);
  @override
  Future<Buffer> execute(Buffer input, Map<String, Object?> args) async =>
      input;
}
