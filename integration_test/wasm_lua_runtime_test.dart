import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/runtime/lua_runtime_asset.dart';
import 'package:bufferite/core/runtime/plugin_runtime.dart';
import 'package:bufferite/core/runtime/sandbox.dart';
import 'package:bufferite/core/runtime/wasm_lua_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late WasmLuaModule module;

  setUpAll(() async {
    module = await loadLuaWasmModule();
  });

  SandboxContext context({Duration? timeout}) {
    return SandboxContext(
      pluginId: 'com.example.wasm',
      operationId: 'wasm.transform',
      config: SandboxConfig(
        stepTimeout: timeout ?? const Duration(seconds: 5),
      ),
    );
  }

  testWidgets('runtime Lua WASM berjalan di device', (tester) async {
    final runtime = WasmLuaRuntime(
      source: 'function transform(input, args) return string.upper(input) end',
      moduleBytes: module.bytes,
    );
    final output = await runtime.execute(
      const TextBuffer('bufferite'),
      const <String, Object?>{},
      context(),
    );
    expect(output.asText(), 'BUFFERITE');
  });

  testWidgets('timeout dari epoch trap menghentikan loop', (tester) async {
    final runtime = WasmLuaRuntime(
      source: 'function transform() while true do end end',
      moduleBytes: module.bytes,
    );
    await expectLater(
      runtime.execute(
        const TextBuffer('x'),
        const <String, Object?>{},
        context(timeout: const Duration(milliseconds: 500)),
      ),
      throwsA(
        isA<AppError>().having(
          (error) => error.code,
          'code',
          'runtime.timeout',
        ),
      ),
    );
  });
}
