import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:continuum_health/main.dart';

void main() {
  testWidgets('App load test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ArdiusCareApp()));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(ArdiusCareApp), findsOneWidget);
  });
}
