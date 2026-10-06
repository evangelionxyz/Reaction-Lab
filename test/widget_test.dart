import 'package:flutter_test/flutter_test.dart';

import 'package:esp32/main.dart';

void main() {
  testWidgets('reaction dashboard renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ReactionApp());

    expect(find.text('REACTION LAB'), findsOneWidget);
    expect(find.text('TEST SETTINGS'), findsOneWidget);
    expect(find.text('REACTION HISTORY'), findsOneWidget);
  });
}
