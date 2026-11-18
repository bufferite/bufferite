import 'package:bufferite/core/engine/buffer.dart';
import 'package:bufferite/core/runtime/lua_runtime.dart';
import 'package:bufferite/core/runtime/sandbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('runtime Lua berjalan di device', (tester) async {
    final runtime = LuaRuntime(
      'function transform(input, args) return string.upper(input) end',
    );
    final output = await runtime.execute(
      const TextBuffer('bufferite'),
      const <String, Object?>{},
      SandboxContext(
        pluginId: 'com.example.lua',
        operationId: 'lua.transform',
        config: SandboxConfig.defaults,
      ),
    );
    expect(output.asText(), 'BUFFERITE');
  });
}