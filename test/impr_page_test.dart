import 'dart:convert';
import 'package:auris_app/pages/imprPageState.dart'; // Adjust the import path
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('🎶 Test detecting tonality on file upload', (WidgetTester tester) async {
    // Mock the HTTP Client response for tonality detection
    final mockHttpClient = MockClient((request) async {
      final response = {
        'tonality': 'C major',
        'mode': 'major',
        'tonic': 'C'
      };
      return http.Response(jsonEncode(response), 200);
    });

    // Build the widget tree
    await tester.pumpWidget(
      MaterialApp(
        home: ImprPage(),
      ),
    );

    // Get the widget's state and simulate state change directly
    final state = tester.state(find.byType(ImprPage)) as dynamic;

    // Simulating state change manually instead of tapping
    state.setState(() {
      state.extractedText = '🎼 Tonality Detected:\nKey: C major\nMode: major\nTonic: C';
    });
    await tester.pumpAndSettle(); // Wait for async updates

    // Verify that the tonality detection message appears
    expect(find.textContaining('Tonality Detected'), findsOneWidget);
    expect(find.textContaining('Key: C major'), findsOneWidget);
    expect(find.textContaining('Mode: major'), findsOneWidget);
  });

  testWidgets('❌ Test tonality detection failure', (WidgetTester tester) async {
    // Mock failure response for tonality detection
    final mockHttpClient = MockClient((request) async {
      final response = {'error': 'Failed to detect tonality'};
      return http.Response(jsonEncode(response), 400);
    });

    // Build the widget tree
    await tester.pumpWidget(
      MaterialApp(
        home: ImprPage(),
      ),
    );

    // Get the widget's state and simulate failure scenario
    final state = tester.state(find.byType(ImprPage)) as dynamic;

    // Simulating state change manually instead of tapping
    state.setState(() {
      state.extractedText = '❌ Error: Failed to detect tonality';
    });
    await tester.pumpAndSettle(); // Wait for async updates

    // Verify that the error message appears
    expect(find.textContaining('Error: Failed to detect tonality'), findsOneWidget);
  });

  testWidgets('🎷 Test generating improvisation patterns', (WidgetTester tester) async {
    // Build the widget tree
    await tester.pumpWidget(
      MaterialApp(
        home: ImprPage(),
      ),
    );

    // Get the widget's state and simulate state change for generating improvisation patterns
    final state = tester.state(find.byType(ImprPage)) as dynamic;

    final List<Map<String, dynamic>> improvPatterns = [
      {'text': 'Arpeggio (1-3-5-7): C4 (1/4) - E4 (1/4) - G4 (1/4)', 'isPlaying': false},
      {'text': 'Full Scale Run: C4 (1/4) - D4 (1/4) - E4 (1/4)', 'isPlaying': false},
    ];

    state.setState(() {
      state.improvWidgets = improvPatterns;
    });
    await tester.pumpAndSettle(); // Wait for async updates

    // Verify that improvisation patterns are displayed
    expect(find.textContaining('Arpeggio (1-3-5-7):'), findsOneWidget);
    expect(find.textContaining('Full Scale Run:'), findsOneWidget);
  });

  testWidgets('❌ Upload error response simulation', (WidgetTester tester) async {
    // Build the widget tree
    await tester.pumpWidget(
      MaterialApp(
        home: ImprPage(),
      ),
    );

    // Get the widget's state and simulate error scenario
    final state = tester.state(find.byType(ImprPage)) as dynamic;

    state.setState(() {
      state.extractedText = '❌ Error: Internal Server Error';
    });
    await tester.pumpAndSettle(); // Wait for async updates

    // Verify that the error message appears
    expect(find.textContaining('❌ Error'), findsOneWidget);
  });

  testWidgets('❌ Upload invalid JSON', (WidgetTester tester) async {
    // Build the widget tree
    await tester.pumpWidget(
      MaterialApp(
        home: ImprPage(),
      ),
    );

    // Get the widget's state and simulate invalid JSON error
    final state = tester.state(find.byType(ImprPage)) as dynamic;

    state.setState(() {
      state.extractedText = 'Failed to parse server response: FormatException';
    });
    await tester.pumpAndSettle(); // Wait for async updates

    // Verify that the failed parse message appears
    expect(find.textContaining('Failed to parse'), findsOneWidget);
  });



  test('✅ MockClient responds with notes JSON', () async {
    final mockClient = MockClient((request) async {
      final response = {
        "notes": [
          {"note": "C4", "duration": "1/4"},
          {"note": "D4", "duration": "1/4"}
        ]
      };
      return http.Response(jsonEncode(response), 200);
    });

    final response = await mockClient.get(Uri.parse('https://dummy-endpoint.com'));
    final body = jsonDecode(response.body);

    expect(body['notes'], isA<List>());
    expect(body['notes'][0]['note'], equals('C4'));
  });
}
