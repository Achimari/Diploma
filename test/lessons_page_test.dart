import 'package:auris_app/pages/lessonPageState.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrapWithMaterial(Widget child) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(1080, 1920)),
        child: child,
      ),
    );
  }

  testWidgets('🎯 Test that initial UI loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(wrapWithMaterial(const LessonsPage()));
    expect(find.text('MASTER NOTES, TRAIN YOUR EARS'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2)); // Play + note buttons
    expect(find.byType(ElevatedButton), findsNothing); // No options yet
  });


  testWidgets('🎼 Note label conversion is correct', (WidgetTester tester) async {
    await tester.pumpWidget(wrapWithMaterial(const LessonsPage()));
    final state = tester.state(find.byType(LessonsPage)) as dynamic;

    expect(state.noteLabel(60), 'C4');
    expect(state.noteLabel(61), 'C#4');
    expect(state.noteLabel(72), 'C5');
    expect(state.noteLabel(48), 'C3');
  });
}
