import 'package:flutter_test/flutter_test.dart';

/// Memompa frame sambil memberi kesempatan event loop nyata agar operasi
/// async (mis. sqflite FFI) selesai.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  int attempts = 60,
  Duration interval = const Duration(milliseconds: 50),
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    if (done()) {
      return;
    }
    await tester.runAsync(() => Future<void>.delayed(interval));
    await tester.pump();
  }
}
