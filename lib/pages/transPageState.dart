import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../Utils/midiServicemidiSservice.dart';

class TransPage extends StatefulWidget {
  const TransPage({super.key});

  @override
  State<TransPage> createState() => _NoteTransPageState();
}

class _NoteTransPageState extends State<TransPage> {
  String extractedText = '';
  bool _isLoading = false;

  List<Map<String, dynamic>> noteWidgets = [];

  int noteToMidiNumber(String note, int octave) {
    const noteMap = {
      'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5,
      'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11
    };
    return 12 * (octave + 1) + (noteMap[note.toUpperCase()] ?? 0);
  }

  Duration parseDuration(String input) {
    switch (input.toLowerCase()) {
      case '1/8':
        return const Duration(milliseconds: 250);
      case '1/4':
        return const Duration(milliseconds: 500);
      case 'half':
        return const Duration(milliseconds: 1000);
      case 'whole':
        return const Duration(milliseconds: 2000);
      default:
        final val = double.tryParse(input);
        return Duration(milliseconds: (val != null ? val * 1000 : 500).toInt());
    }
  }

  Future<void> playExtractedNotes() async {
    final midiPro = MidiService().midiPro;
    final sfId = MidiService().soundFontId;
    if (sfId == null) return;

    final regex = RegExp(r'([A-G][#b]?)(\d)\s*\(([^)]+)\)');
    final matches = regex.allMatches(noteWidgets.map((n) => n['text']).join(','));

    int currentNoteIndex = 0;

    for (final match in matches) {
      final note = match.group(1)!;
      final octave = int.parse(match.group(2)!);
      final durationStr = match.group(3)!;
      final midi = noteToMidiNumber(note, octave);
      final duration = parseDuration(durationStr);

      setState(() {
        if (currentNoteIndex < noteWidgets.length) {
          noteWidgets[currentNoteIndex]['isPlaying'] = true;
        }
      });

      midiPro.playNote(
        sfId: sfId,
        channel: 0,
        key: midi,
        velocity: 127,
      );

      await Future.delayed(duration);

      midiPro.stopNote(
        sfId: sfId,
        channel: 0,
        key: midi,
      );

      setState(() {
        if (currentNoteIndex < noteWidgets.length) {
          noteWidgets[currentNoteIndex]['isPlaying'] = false;
        }
      });

      currentNoteIndex++;
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final file = result.files.single;
      final filePath = file.path!;
      String fileName = file.name;

      if (!fileName.contains('.') && file.extension != null) {
        fileName += '.${file.extension}';
      }

      setState(() => _isLoading = true);

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://cleanup-movie-periods-floors.trycloudflare.com/extract-notes'),
      );

      request.files.add(await http.MultipartFile.fromPath(
        'image',
        filePath,
        filename: fileName,
      ));

      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      try {
        final decoded = jsonDecode(respStr);

        setState(() {
          _isLoading = false;
          noteWidgets = [];

          if (decoded['notes'] != null && decoded['notes'] is List) {
            List<dynamic> noteList = decoded['notes'];
            for (var n in noteList) {
              final note = n['note'] ?? '?';
              final dur = n['duration'] ?? '?';
              noteWidgets.add({
                'text': '$note ($dur)',
                'isPlaying': false,
              });
            }
            extractedText = '🎼 Melody:';
          } else if (decoded['message'] != null) {
            extractedText = decoded['message'];
          } else if (decoded['error'] != null) {
            extractedText = '❌ Error: ${decoded['error']}';
          } else {
            extractedText = '❓ Unknown response from server.';
          }
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
          extractedText = 'Failed to parse server response: $e';
        });
      }
    }
  }

  void convertNotesToSaxophone() {
    if (extractedText.contains('Transposed for Saxophone')) return;

    final List<String> chromatic = [
      'C', 'C#', 'D', 'D#', 'E', 'F',
      'F#', 'G', 'G#', 'A', 'A#', 'B'
    ];

    final Map<String, String> enharmonicMap = {
      'Db': 'C#', 'Eb': 'D#', 'Fb': 'E', 'E#': 'F',
      'Gb': 'F#', 'Ab': 'G#', 'Bb': 'A#', 'Cb': 'B'
    };

    final Map<String, int> noteToIndex = {
      for (int i = 0; i < chromatic.length; i++) chromatic[i]: i
    };

    List<int> tryTransposition(int semitoneShift) {
      List<int> result = [];
      for (final noteMap in noteWidgets) {
        final text = noteMap['text'] as String;
        final regex = RegExp(r'^([A-G][#b]?)(\d)\s*\(([^)]+)\)$');
        final match = regex.firstMatch(text);
        if (match == null) return [];

        String note = match[1]!.replaceAll('♯', '#').replaceAll('♭', 'b').toUpperCase();
        note = enharmonicMap[note] ?? note;
        int octave = int.tryParse(match[2]!) ?? 4;
        int baseIndex = noteToIndex[note]!;
        int midi = 12 * (octave + 1) + baseIndex + semitoneShift;
        result.add(midi);
      }
      return result;
    }

    int? finalShift;
    int? chosenSemitoneTransposition;
    List<int> finalMidiNotes = [];

    List<int> primaryTransposed = tryTransposition(9);
    if (primaryTransposed.isNotEmpty &&
        primaryTransposed.every((midi) => midi >= 58 && midi <= 89)) {
      finalMidiNotes = primaryTransposed;
      finalShift = 0;
      chosenSemitoneTransposition = 9;
    } else {
      final baseTransposed = tryTransposition(3);
      for (final globalShift in [0, -12, 12]) {
        final shifted = baseTransposed.map((m) => m + globalShift).toList();
        final isValid = shifted.every((m) => m >= 58 && m <= 89);
        if (isValid) {
          finalMidiNotes = shifted;
          finalShift = globalShift;
          chosenSemitoneTransposition = 3;
          break;
        }
      }
    }

    if (finalMidiNotes.isEmpty || chosenSemitoneTransposition == null) {
      setState(() {
        extractedText = '❌ Transposition failed: notes out of saxophone range.';
      });
      return;
    }

    String shiftLabel = '';
    if (chosenSemitoneTransposition == 9) {
      shiftLabel = ' (standard +9 semitones)';
    } else {
      shiftLabel = ' ⚠️ alternative +3 semitones used';
      if (finalShift == -12) shiftLabel += ', shifted down 1 octave';
      if (finalShift == 12) shiftLabel += ', shifted up 1 octave';
    }

    List<Map<String, dynamic>> transposedWidgets = [];
    for (int i = 0; i < noteWidgets.length; i++) {
      final original = noteWidgets[i]['text'] as String;
      final regex = RegExp(r'^([A-G][#b]?)(\d)\s*\(([^)]+)\)$');
      final match = regex.firstMatch(original);
      if (match == null) continue;

      final duration = match[3] ?? '?';
      final midi = finalMidiNotes[i];
      final noteIndex = midi % 12;
      final octave = (midi ~/ 12) - 1;
      final noteName = chromatic[noteIndex];

      transposedWidgets.add({
        'text': '$noteName$octave ($duration)',
        'isPlaying': false,
      });
    }

    setState(() {
      noteWidgets = transposedWidgets;
      extractedText = '🎷 Transposed for Saxophone$shiftLabel:';
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 40),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'SEAMLESS SOUND SHIFT: PIANO TO SAX MADE EASY',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _isLoading ? null : pickAndUploadFile,
                child: Column(
                  children: [
                    Image.asset('assets/uploudButton.png', width: 150),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.white,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          extractedText,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: noteWidgets.map((noteMap) {
                            final text = noteMap['text'] as String;
                            final isPlaying = noteMap['isPlaying'] as bool;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isPlaying ? Colors.orangeAccent : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey),
                              ),
                              child: Text(
                                text,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                                  color: isPlaying ? Colors.black : Colors.grey[800],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _isLoading ? null : convertNotesToSaxophone,
                      child: Image.asset('assets/convertButton.png', width: 100),
                    ),
                    Image.asset('assets/actIcon.png', width: 40),
                    GestureDetector(
                      onTap: _isLoading ? null : playExtractedNotes,
                      child: Image.asset('assets/buttonPlay.png', width: 100),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
