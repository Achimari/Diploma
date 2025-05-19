import 'dart:convert';

import 'package:auris_app/pages/transPageState.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MockTransPageState {
  int noteToMidiNumber(String note, int octave) {
    const noteMap = {
      'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5,
      'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11
    };
    return 12 * (octave + 1) + (noteMap[note.toUpperCase()] ?? 0);
  }
}

void main() {
  testWidgets('✅ UI loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TransPage()));
    expect(find.text(''), findsOneWidget);
    expect(find.text('SEAMLESS SOUND SHIFT: PIANO TO SAX MADE EASY'), findsOneWidget);
  });

  testWidgets('✅ Transposition succeeds', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TransPage()));
    final state = tester.state(find.byType(TransPage)) as dynamic;

    state.setState(() {
      state.noteWidgets = [
        {'text': 'C4 (1/4)', 'isPlaying': false},
        {'text': 'D4 (1/4)', 'isPlaying': false},
      ];
      state.extractedText = '🎼 Melody:';
    });
    await tester.pump();

    state.convertNotesToSaxophone();
    await tester.pumpAndSettle();

    expect(find.textContaining('Transposed for Saxophone'), findsOneWidget);
  });

  testWidgets('❌ Transposition fails (notes out of range)', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TransPage()));
    final state = tester.state(find.byType(TransPage)) as dynamic;

    state.setState(() {
      state.noteWidgets = [
        {'text': 'B8 (1/4)', 'isPlaying': false},
        {'text': 'C9 (1/4)', 'isPlaying': false},
      ];
      state.extractedText = '🎼 Melody:';
    });
    await tester.pump();

    state.convertNotesToSaxophone();
    await tester.pumpAndSettle();

    expect(find.textContaining('❌ Transposition failed'), findsOneWidget);
  });

  testWidgets('✅ Upload simulation (notes displayed)', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TransPage()));
    final state = tester.state(find.byType(TransPage)) as dynamic;

    final List<Map<String, dynamic>> parsedNotes = [
      {"note": "C4", "duration": "1/4"},
      {"note": "D4", "duration": "1/4"}
    ];

    state.setState(() {
      state.noteWidgets = parsedNotes.map((n) => {
        'text': '${n['note']} (${n['duration']})',
        'isPlaying': false,
      }).toList();
      state.extractedText = '🎼 Melody:';
    });
    await tester.pumpAndSettle();

    expect(find.text('C4 (1/4)'), findsOneWidget);
    expect(find.text('D4 (1/4)'), findsOneWidget);
  });

  testWidgets('❌ Upload error response simulation', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TransPage()));
    final state = tester.state(find.byType(TransPage)) as dynamic;

    state.setState(() {
      state.noteWidgets = <Map<String, dynamic>>[];
      state.extractedText = '❌ Error: Internal Server Error';
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('❌ Error'), findsOneWidget);
  });

  testWidgets('❌ Upload invalid JSON', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TransPage()));
    final state = tester.state(find.byType(TransPage)) as dynamic;

    state.setState(() {
      state.noteWidgets = <Map<String, dynamic>>[];
      state.extractedText = 'Failed to parse server response: FormatException';
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to parse'), findsOneWidget);
  });

  testWidgets('⛔ Upload canceled (no result)', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TransPage()));
    final state = tester.state(find.byType(TransPage)) as dynamic;
    final before = state.extractedText;
    await tester.pumpAndSettle();

    expect(state.noteWidgets.length, equals(0));
    expect(state.extractedText, equals(before));
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

  group('🎼 noteToMidiNumber()', () {
    final state = MockTransPageState();

    test('returns correct MIDI number for uppercase notes', () {
      expect(state.noteToMidiNumber('C', 4), 60);
      expect(state.noteToMidiNumber('A', 4), 69);
      expect(state.noteToMidiNumber('G#', 3), 56);
    });

    test('returns correct MIDI number for lowercase notes', () {
      expect(state.noteToMidiNumber('d#', 5), 75);
      expect(state.noteToMidiNumber('b', 0), 23);
    });

    test('returns fallback value when note is unknown', () {
      expect(state.noteToMidiNumber('???', 4), 60); // 12 * (4 + 1) + 0
    });
  });
}