import 'package:flutter_test/flutter_test.dart';

import 'package:esp32/main.dart';

void main() {
  testWidgets('reaction dashboard renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ReactionApp());
    await tester.pumpAndSettle();

    expect(find.text('Reaction Lab'), findsOneWidget);
    expect(find.text('TEST SETTINGS'), findsOneWidget);
    expect(find.text('REACTION TIME'), findsOneWidget);
    expect(find.text('Minimum stop time'), findsOneWidget);
    expect(find.text('Maximum stop time'), findsOneWidget);
    expect(find.text('Green brightness'), findsOneWidget);
    expect(find.text('Red brightness'), findsOneWidget);
    expect(find.text('Sync Settings'), findsOneWidget);
    expect(find.text('Start Test'), findsNothing);
    expect(find.text('Simulator Aktif'), findsNothing);
  });
}
