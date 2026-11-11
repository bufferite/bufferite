import 'package:bufferite/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots and shows empty state', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BufferiteApp()));

    expect(find.text('Bufferite'), findsOneWidget);
    expect(find.text('Belum ada recipe'), findsOneWidget);
    expect(
      find.text(
        'Racik data dengan resep. Recipe builder akan tersedia '
        'setelah fondasi selesai.',
      ),
      findsOneWidget,
    );
  });
}
