import 'dart:convert';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../Utils/midiServicemidiSservice.dart';

class ImprPage extends StatefulWidget {
  const ImprPage({super.key});

  @override
  State<ImprPage> createState() => _ImprPageState();
}

class _ImprPageState extends State<ImprPage> with SingleTickerProviderStateMixin {
  String extractedText = '';
  bool _isLoading = false;
  final _rand = Random();
  List<Map<String, dynamic>> improvWidgets = [];

  int noteToMidiNumber(String note, int octave) {
    const noteMap = {
      'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5,
      'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11
    };
    return 12 * (octave + 1) + (noteMap[note.toUpperCase()] ?? 0);
  }

  Future<void> playImprovPatterns() async {
    final midiPro = MidiService().midiPro;
    final sfId = MidiService().soundFontId;
    if (sfId == null || improvWidgets.isEmpty) return;

    final regex = RegExp(r'([A-G][#b]?)(?:\s*\(([^)]+)\))?');
    int currentLineIndex = 0;

    for (final map in improvWidgets) {
      final match = RegExp(r':\s*(.+)$').firstMatch(map['text']);
      if (match == null) continue;

      final notes = match.group(1)!.split('-').map((n) => n.trim()).toList();

      for (final note in notes) {
        final m = regex.firstMatch(note);
        if (m != null) {
          final baseNote = m.group(1)!;
          final durationLabel = m.group(2) ?? '1/4';
          final midi = noteToMidiNumber(baseNote, 4);
          final duration = parseDuration(durationLabel);

          setState(() {
            improvWidgets[currentLineIndex]['isPlaying'] = true;
          });

          midiPro.playNote(sfId: sfId, channel: 0, key: midi, velocity: 127);
          await Future.delayed(duration);
          midiPro.stopNote(sfId: sfId, channel: 0, key: midi);

          setState(() {
            improvWidgets[currentLineIndex]['isPlaying'] = false;
          });

          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      currentLineIndex++;
    }
  }

  Future<void> pickAndDetectTonality() async {
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

      setState(() {
        _isLoading = true;
        extractedText = 'Detecting tonality... 🎶';
      });

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://sip-pty-celebrate-truck.trycloudflare.com/detect-tonality'),
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
          if (decoded['tonality'] != null) {
            extractedText =
            '🎼 Tonality Detected:\nKey: ${decoded['tonality']}\nMode: ${decoded['mode']}\nTonic: ${decoded['tonic']}';
          } else if (decoded['error'] != null) {
            extractedText = '❌ Error: ${decoded['error']}';
          } else {
            extractedText = '❓ Unexpected response.';
          }
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
          extractedText = '❌ Failed to parse response: $e';
        });
      }
    }
  }

  void generateImprovisationPatterns() {
    final regex = RegExp(
      r'Key: ([A-Ga-g][#b]?)[ ]?(major|minor|natural minor|harmonic minor|melodic minor|dorian|phrygian|lydian|mixolydian|locrian|blues|major pentatonic|minor pentatonic|whole tone|octatonic|diminished|double harmonic|hungarian minor)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(extractedText);
    if (match == null) {
      setState(() {
        extractedText += '\n\n❗ Unable to extract key for improvisation.';
      });
      return;
    }

    final tonic = match.group(1)!.toUpperCase();
    final mode = match.group(2)!.toLowerCase();

    final chromatic = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final enharmonic = {
      'Db': 'C#', 'Eb': 'D#', 'Gb': 'F#', 'Ab': 'G#', 'Bb': 'A#',
    };

    String resolveTonic(String note) {
      final upper = note.toUpperCase();
      return chromatic.contains(upper) ? upper : (enharmonic[upper] ?? 'C');
    }

    final root = resolveTonic(tonic);
    final rootIndex = chromatic.indexOf(root);

    final modeIntervals = {
      'major': [0, 2, 4, 5, 7, 9, 11],
      'minor': [0, 2, 3, 5, 7, 8, 10],
      'natural minor': [0, 2, 3, 5, 7, 8, 10],
      'harmonic minor': [0, 2, 3, 5, 7, 8, 11],
      'melodic minor': [0, 2, 3, 5, 7, 9, 11],
      'dorian': [0, 2, 3, 5, 7, 9, 10],
      'phrygian': [0, 1, 3, 5, 7, 8, 10],
      'lydian': [0, 2, 4, 6, 7, 9, 11],
      'mixolydian': [0, 2, 4, 5, 7, 9, 10],
      'locrian': [0, 1, 3, 5, 6, 8, 10],
      'blues': [0, 3, 5, 6, 7, 10],
      'major pentatonic': [0, 2, 4, 7, 9],
      'minor pentatonic': [0, 3, 5, 7, 10],
      'whole tone': [0, 2, 4, 6, 8, 10],
      'octatonic': [0, 2, 3, 5, 6, 8, 9, 11],
      'diminished': [0, 2, 3, 5, 6, 8, 9, 11],
      'double harmonic': [0, 1, 4, 5, 7, 8, 11],
      'hungarian minor': [0, 2, 3, 6, 7, 8, 11],
    };

    final intervals = modeIntervals[mode] ?? modeIntervals['major']!;
    final scale = intervals.map((i) => chromatic[(rootIndex + i) % 12]).toList();

    final pentatonic = (['major', 'lydian', 'mixolydian'].contains(mode))
        ? [0, 2, 4, 7, 9]
        : [0, 3, 5, 7, 10];
    final pentatonicNotes = pentatonic.map((i) => chromatic[(rootIndex + i) % 12]).toList();

    final chordTones = [
      scale[0],
      if (scale.length > 2) scale[2],
      if (scale.length > 4) scale[4],
      if (scale.length > 6) scale[6],
    ];

    final descendingPhrase = [
      scale.length > 4 ? scale[4] : scale.last,
      scale.length > 1 ? scale[1] : scale.first,
      scale[0],
      scale.length > 4 ? scale[4] : scale.last,
    ];

    final guideTones = [
      if (scale.length > 2) scale[2],
      if (scale.length > 6) scale[6],
      if (scale.length > 2) scale[2],
      if (scale.length > 6) scale[6],
    ];

    final bebopScale = (scale.length == 7 && scale.contains(scale[4]) && scale.contains(scale[5]))
        ? [...scale.sublist(0, 5), chromatic[(rootIndex + 8) % 12], ...scale.sublist(5)]
        : scale;

    final enclosures = [
      scale[2], // 3rd
      chromatic[(chromatic.indexOf(scale[2]) + 1) % 12],
      chromatic[(chromatic.indexOf(scale[2]) - 1 + 12) % 12],
      scale[2],
    ];

    final quartal = [
      scale[0],
      scale.length > 3 ? scale[3] : scale[2],
      scale.length > 6 ? scale[6] : scale.last,
    ];

    final modalLine = scale.sublist(1, 6);

    final patterns = [
      'Arpeggio (1-3-5-7): ${chordTones.map((n) => '$n (${_randomDuration()})').join(' - ')}',
      'Full Scale Run: ${scale.map((n) => '$n (${_randomDuration()})').join(' - ')}',
      'Pentatonic Line: ${pentatonicNotes.map((n) => '$n (${_randomDuration()})').join(' - ')}',
      'Descending Phrase: ${descendingPhrase.map((n) => '$n (${_randomDuration()})').join(' - ')}',
      'Guide Tone Line (3rds & 7ths): ${guideTones.map((n) => '$n (${_randomDuration()})').join(' - ')}',
      'Bebop Scale Line (if applicable): ${bebopScale.map((n) => '$n (${_randomDuration()})').join(' - ')}',
      'Enclosure (Target 3rd): ${enclosures.map((n) => '$n (${_randomDuration()})').join(' - ')}',
      'Quartal Harmony (stacked 4ths): ${quartal.map((n) => '$n (${_randomDuration()})').join(' - ')}',
      'Modal Centered Line: ${modalLine.map((n) => '$n (${_randomDuration()})').join(' - ')}',
    ];

    final patternList = patterns.map((p) => {
      'text': p,
      'isPlaying': false,
    }).toList();

    setState(() {
      extractedText = '🎷 Notes for Improvisation in $tonic ${mode[0].toUpperCase()}${mode.substring(1)}:\n${scale.join(', ')}';
      improvWidgets = patternList;
    });

  }


  String _randomDuration() {
    final options = ['1/8', '1/4', '1/4', '1/16', '1/8', 'half'];
    return options[_rand.nextInt(options.length)];
  }

  Duration parseDuration(String input) {
    switch (input.toLowerCase()) {
      case '1/16': return const Duration(milliseconds: 125);
      case '1/8': return const Duration(milliseconds: 250);
      case '1/4': return const Duration(milliseconds: 500);
      case 'half': return const Duration(milliseconds: 1000);
      case 'whole': return const Duration(milliseconds: 2000);
      default: return const Duration(milliseconds: 400);
    }
  }

  void showManualTonalityPicker() async {
    final keys = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final modes = ['major', 'minor'];

    String selectedKey = keys[0];
    String selectedMode = modes[0];

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Choose Tonality'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: selectedKey,
                    isExpanded: true,
                    items: keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedKey = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButton<String>(
                    value: selectedMode,
                    isExpanded: true,
                    items: modes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedMode = val);
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  extractedText =
                  '🎼 Tonality Detected:\nKey: $selectedKey $selectedMode\nMode: $selectedMode\nTonic: $selectedKey';
                });
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
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
                  'SMART JAMS, INSTANT VIBES',
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
                onTap: _isLoading ? null : pickAndDetectTonality,
                child: Image.asset('assets/uploudButton.png', width: 150),
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
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: improvWidgets.map((map) {
                            final text = map['text'] as String;
                            final isPlaying = map['isPlaying'] as bool;
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
                      onTap: _isLoading ? null : generateImprovisationPatterns,
                      child: Image.asset('assets/generateButton.png', width: 100),
                    ),
                    GestureDetector(
                      onTap: _isLoading ? null : showManualTonalityPicker,
                      child: Image.asset('assets/actIcon.png', width: 40),
                    ),
                    GestureDetector(
                      onTap: _isLoading ? null : playImprovPatterns,
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
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}
