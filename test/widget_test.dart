import 'package:flutter_test/flutter_test.dart';

import 'package:sih/main.dart';

void main() {
  testWidgets('SIH app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const SIHApp());

    expect(find.byType(SIHApp), findsOneWidget);
  });
}
