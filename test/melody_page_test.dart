import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auris_app/pages/melodyPageState.dart';

void main() {
  testWidgets('🍼 convertAndStylizeMelodyUsingTheory displays stylized notes', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MelodyPage()));

    final state = tester.state(find.byType(MelodyPage)) as dynamic;

    // Simulate raw notes in extractedText (bypassing actual recording logic)
    state.setState(() {
      state.extractedText = '🎼 Raw Notes:\nC4, D4, E4, F4, G4';
    });

    await tester.pump();
    state.convertAndStylizeMelodyUsingTheory();
    await tester.pumpAndSettle();

    expect(find.textContaining('🎵 Melody:'), findsOneWidget);
    expect(state.noteWidgets.length, greaterThan(0));
  });

  testWidgets('🧪 tapping convert button triggers stylization', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MelodyPage()));

    final state = tester.state(find.byType(MelodyPage)) as dynamic;

    state.setState(() {
      state.extractedText = '🎼 Raw Notes:\nC4, D4';
    });

    await tester.pump();

    final convertBtn = find.byWidgetPredicate((widget) =>
    widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName.contains('convertButton'));

    expect(convertBtn, findsOneWidget);
    await tester.tap(convertBtn);
    await tester.pumpAndSettle();

    expect(state.noteWidgets.length, greaterThan(0));
    expect(find.textContaining('🎵 Melody:'), findsOneWidget);
  });
}
