import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:treasure_or_trash_app/app_state.dart';
import 'package:treasure_or_trash_app/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => AppState(),
        child: const TreasureOrTrashApp(),
      ),
    );

    // Verify that the title and navigation are present
    expect(find.text('Trash or Treasure'), findsWidgets);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Pinned'), findsOneWidget);
  });
}
