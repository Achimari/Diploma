import 'package:flutter/material.dart';
import 'dart:math';

import '../Utils/midiServicemidiSservice.dart';

class LessonsPage extends StatefulWidget {
  const LessonsPage({Key? key}) : super(key: key);

  @override
  State<LessonsPage> createState() => _LessonsPageState();
}

class _LessonsPageState extends State<LessonsPage> {
  int? _currentNote;
  int? _correctAnswer;

  static const int saxMinNote = 58;
  static const int saxMaxNote = 89;

  bool _buttonsDisabled = false;
  List<int> _noteOptions = [];

  int? _selectedNote;
  bool? _isCorrect;

  void _generateRandomNote() {
    if (_buttonsDisabled) return;

    final random = Random();
    const minConcertNote = saxMinNote - 9;
    const maxConcertNote = saxMaxNote - 9;

    final note = minConcertNote + random.nextInt(maxConcertNote - minConcertNote + 1);
    final correct = note + 9;

    final Set<int> options = {correct};
    while (options.length < 4) {
      final randomConcert = minConcertNote + random.nextInt(maxConcertNote - minConcertNote + 1);
      final randomSaxNote = randomConcert + 9;
      if (randomSaxNote != correct) {
        options.add(randomSaxNote);
      }
    }

    setState(() {
      _currentNote = note;
      _correctAnswer = correct;
      _noteOptions = options.toList()..shuffle();
      _selectedNote = null;
      _isCorrect = null;
    });

    _playNote();
  }

  void _playNote() {
    if (_buttonsDisabled) return;
    final midiPro = MidiService().midiPro;
    final sfId = MidiService().soundFontId;
    if (_currentNote != null && sfId != null) {
      midiPro.playNote(
        sfId: sfId,
        channel: 0,
        key: _currentNote!,
        velocity: 127,
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        midiPro.stopNote(
          sfId: sfId,
          channel: 0,
          key: _currentNote!,
        );
      });
    }
  }

  String noteLabel(int midiNumber) {
    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final octave = (midiNumber ~/ 12) - 1;
    final name = noteNames[midiNumber % 12];
    return '$name$octave';
  }

  void _checkAnswer(int selectedNote) async {
    if (_buttonsDisabled) return;

    final midiPro = MidiService().midiPro;
    final sfId = MidiService().soundFontId;
    if (sfId == null) return;

    setState(() {
      _buttonsDisabled = true;
      _selectedNote = selectedNote;
      _isCorrect = selectedNote == _correctAnswer;
    });

    midiPro.playNote(
      sfId: sfId,
      channel: 0,
      key: selectedNote,
      velocity: 127,
    );

    await Future.delayed(const Duration(milliseconds: 500));
    midiPro.stopNote(
      sfId: sfId,
      channel: 0,
      key: selectedNote,
    );

    await Future.delayed(const Duration(milliseconds: 1200));

    setState(() {
      _buttonsDisabled = false;
      _selectedNote = null;
      _isCorrect = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 40),
          const Text(
            'MASTER NOTES, TRAIN YOUR EARS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: _playNote,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/buttonPlay.png', width: 130),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _generateRandomNote,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/note.png', width: 150),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_currentNote != null) ...[
                  Text(
                    'You heard: ${noteLabel(_currentNote!)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
                ..._noteOptions.map((note) {
                  final bool isSelected = _selectedNote == note;
                  final bool showResultColor = _buttonsDisabled && _selectedNote != null;

                  Color buttonColor = const Color(0xFF2D2D2D); // default

                  if (showResultColor) {
                    if (isSelected) {
                      buttonColor = _isCorrect == true ? Colors.green : Colors.red;
                    } else {
                      buttonColor = Colors.grey.shade300;
                    }
                  } else {
                    buttonColor = const Color(0xFF2D2D2D);
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ).copyWith(
                        backgroundColor: MaterialStateProperty.resolveWith<Color>(
                              (states) => buttonColor,
                        ),
                      ),
                      onPressed: _buttonsDisabled
                          ? null
                          : () {
                        _checkAnswer(note);
                      },
                      child: Text(
                        noteLabel(note),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Gothic A1',
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
