import 'package:flutter_test/flutter_test.dart';
import 'package:treasure_or_trash_app/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TreasureOrTrashApp());

    // Verify that the title is present
    expect(find.text('Treasure or Trash'), findsWidgets);
    expect(find.text('AI Pricing Expert'), findsOneWidget);
  });
}