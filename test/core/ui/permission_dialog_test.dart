import 'package:bufferite/core/plugin/plugin_permission.dart';
import 'package:bufferite/core/ui/app_theme.dart';
import 'package:bufferite/core/ui/components/permission_dialog.dart';
import 'package:bufferite/core/ui/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({required Future<void> Function(BuildContext context) onPressed}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => onPressed(context),
            child: const Text('Buka'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('menampilkan daftar izin dan judul jaringan', (tester) async {
    await tester.pumpWidget(
      _host(
        onPressed: (context) => showPermissionDialog(
          context,
          pluginName: 'Test Pack',
          permissions: const <PluginPermission>{
            PluginPermission.cpu,
            PluginPermission.net,
          },
        ),
      ),
    );

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    expect(find.text('Plugin meminta akses internet'), findsOneWidget);
    expect(find.text('cpu — memproses data di perangkat'), findsOneWidget);
    expect(find.text('net — mengakses internet'), findsOneWidget);
  });

  testWidgets('tap luar tidak menutup dialog', (tester) async {
    await tester.pumpWidget(
      _host(
        onPressed: (context) => showPermissionDialog(
          context,
          pluginName: 'Test Pack',
          permissions: const <PluginPermission>{PluginPermission.cpu},
        ),
      ),
    );

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('Setujui'), findsOneWidget);
  });

  testWidgets('Batal mengembalikan false dan Setujui true', (tester) async {
    bool? result;
    await tester.pumpWidget(
      _host(
        onPressed: (context) async {
          result = await showPermissionDialog(
            context,
            pluginName: 'Test Pack',
            permissions: const <PluginPermission>{PluginPermission.cpu},
          );
        },
      ),
    );

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Setujui'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('izin net memakai tombol danger', (tester) async {
    await tester.pumpWidget(
      _host(
        onPressed: (context) => showPermissionDialog(
          context,
          pluginName: 'Test Pack',
          permissions: const <PluginPermission>{PluginPermission.net},
        ),
      ),
    );

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    final color = button.style?.backgroundColor?.resolve(<WidgetState>{});
    expect(color, AppPalette.light.danger);
  });
}
