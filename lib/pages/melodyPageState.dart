import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

import '../Utils/midiServicemidiSservice.dart';

class MelodyPage extends StatefulWidget {
  const MelodyPage({Key? key}) : super(key: key);

  @override
  State<MelodyPage> createState() => _MelodyPageState();
}

class _MelodyPageState extends State<MelodyPage> with SingleTickerProviderStateMixin {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  String extractedText = '';
  String? recordedFilePath;
  Duration? _recordedDuration;
  bool _isLoading = false;

  List<Map<String, dynamic>> noteWidgets = [];

  Future<void> startRecordingProcess() async {
    setState(() {
      _isLoading = true;
      extractedText = '⏳ Starting in 2 seconds...';
    });
    await Future.delayed(const Duration(seconds: 2));
    await Permission.microphone.request();
    final dir = await getTemporaryDirectory();
    recordedFilePath = '${dir.path}/melody.wav';
    await _recorder.openRecorder();
    await _recorder.startRecorder(
      toFile: recordedFilePath!,
      codec: Codec.pcm16WAV,
    );
    setState(() {
      _isRecording = true;
      _isLoading = false;
      extractedText = '🎤 Recording...';
    });
  }

  Future<void> stopRecording() async {
    await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
      _isLoading = true;
      extractedText = '🎼 Transforming melody into notes...';
    });
    if (recordedFilePath != null) {
      final file = File(recordedFilePath!);
      final dur = await getWavDuration(file);
      if (dur != null) {
        setState(() {
          _recordedDuration = dur;
        });
      }
      await sendToNoteAPI(File(recordedFilePath!));
    } else {
      setState(() {
        extractedText = '❌ Recording failed.';
      });
    }
  }

  Future<Duration?> getWavDuration(File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length < 44) return null;
    final byteData = ByteData.sublistView(bytes);
    final sampleRate = byteData.getUint32(24, Endian.little);
    final dataLength = byteData.getUint32(40, Endian.little);
    final durationInSeconds = dataLength / (sampleRate * 2); // mono, 16-bit
    return Duration(milliseconds: (durationInSeconds * 1000).round());
  }

  Future<void> sendToNoteAPI(File audioFile) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://sip-pty-celebrate-truck.trycloudflare.com/extract-notes-from-audio'),
    );
    request.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));
    try {
      final response = await request.send();
      final result = await http.Response.fromStream(response);
      if (result.statusCode == 200) {
        final data = json.decode(result.body);
        List<String> rawNotes = (data['notes'] as List)
            .map<String>((n) => n.toString())
            .toList();
        setState(() {
          _isLoading = false;
          extractedText = '🎼 Raw Notes:\n${rawNotes.join(', ')}';
        });
      } else {
        setState(() {
          extractedText = '❌ Server error ${result.statusCode}: ${result.body}';
        });
      }
    } catch (e) {
      setState(() {
        extractedText = '❌ Error: $e';
      });
    }
  }

  int noteToMidiNumber(String note, int octave) {
    const noteMap = {
      'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5,
      'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11,
    };
    return 12 * (octave + 1) + (noteMap[note.toUpperCase()] ?? 0);
  }

  Future<void> playExtractedNotes() async {
    final midiPro = MidiService().midiPro;
    final sfId = MidiService().soundFontId;
    if (sfId == null || noteWidgets.isEmpty) return;

    final regex = RegExp(r'([A-G][#b]?)(\d)\s*\(([^)]+)\)');
    int currentNoteIndex = 0;

    for (final noteMap in noteWidgets) {
      final match = regex.firstMatch(noteMap['text']);
      if (match == null) continue;

      final note = match.group(1)!;
      final octave = int.parse(match.group(2)!);
      final durationLabel = match.group(3)!;

      final duration = {
        '1/32': const Duration(milliseconds: 62),
        '1/16': const Duration(milliseconds: 125),
        '1/8': const Duration(milliseconds: 250),
        '1/4': const Duration(milliseconds: 500),
        'half': const Duration(milliseconds: 1000),
        'whole': const Duration(milliseconds: 2000),
      }[durationLabel] ?? const Duration(milliseconds: 250);

      final midi = noteToMidiNumber(note, octave);

      setState(() {
        noteWidgets[currentNoteIndex]['isPlaying'] = true;
      });

      midiPro.playNote(sfId: sfId, channel: 0, key: midi, velocity: 127);
      await Future.delayed(duration);
      midiPro.stopNote(sfId: sfId, channel: 0, key: midi);

      setState(() {
        noteWidgets[currentNoteIndex]['isPlaying'] = false;
      });

      currentNoteIndex++;
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void convertAndStylizeMelodyUsingTheory() {
    const saxMinNote = 58;
    const saxMaxNote = 89;

    final raw = extractedText.replaceFirst(RegExp(r'🎼 Raw Notes:\n|🎷 Alto Sax:\n|🎶 Improved Melody:\n|🎵 Melody:\n'), '');
    final noteList = raw.split(',').map((n) => n.trim()).where((n) => n.isNotEmpty).toList();

    final scale = ['G', 'A', 'B', 'C', 'D', 'E', 'F#'];
    final chordTones = {
      'I': ['G', 'B', 'D'],
      'IV': ['C', 'E', 'G'],
      'V': ['D', 'F#', 'A']
    };
    final durations = ['1/32', '1/16', '1/8', '1/4', '1/4', '1/8', 'half', 'whole'];
    final durationMap = {
      '1/32': Duration(milliseconds: 62),
      '1/16': Duration(milliseconds: 125),
      '1/8': Duration(milliseconds: 250),
      '1/4': Duration(milliseconds: 500),
      'half': Duration(milliseconds: 1000),
      'whole': Duration(milliseconds: 2000),
    };

    final chromatic = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final enharmonicMap = {'Db': 'C#', 'Eb': 'D#', 'Gb': 'F#', 'Ab': 'G#', 'Bb': 'A#'};

    int noteToMidi(String note, int octave) {
      final idx = chromatic.indexOf(note);
      return 12 * (octave + 1) + idx;
    }

    String midiToNote(int midi) {
      final note = chromatic[midi % 12];
      final oct = (midi ~/ 12) - 1;
      return '$note$oct';
    }

    MapEntry<String, int> replaceWithNearestPlayable(String baseNote, int baseOctave, List<String> fallbackPool) {
      for (int shift = 0; shift <= 2; shift++) {
        for (final alt in fallbackPool) {
          for (final dir in [1, -1]) {
            final oct = baseOctave + (dir * shift);
            final midi = noteToMidi(alt, oct);
            if (midi >= saxMinNote && midi <= saxMaxNote) {
              return MapEntry('$alt$oct', midi - noteToMidi(baseNote, baseOctave));
            }
          }
        }
      }
      return const MapEntry('G4', 0);
    }

    List<String> result = [];
    List<String> motif = [];
    int motifCount = 0;
    Duration totalDuration = Duration.zero;

    for (int i = 0; i < noteList.length; i++) {
      if (_recordedDuration != null && totalDuration >= _recordedDuration!) break;
      final match = RegExp(r'^([A-Ga-g][#b]?)(\d)$').firstMatch(noteList[i]);
      if (match != null) {
        String note = match.group(1)!.toUpperCase();
        int octave = int.parse(match.group(2)!);
        note = enharmonicMap[note] ?? note;
        int index = chromatic.indexOf(note);
        int newIndex = (index + 9) % 12;
        int octaveShift = (index + 9) ~/ 12;
        String newNote = chromatic[newIndex];
        int newOctave = octave + octaveShift;

        int midi = noteToMidi(newNote, newOctave);
        final baseNote = newNote.replaceAll(RegExp(r'#|b'), '');
        final duration = durations[(i + baseNote.codeUnitAt(0)) % durations.length];
        final dur = durationMap[duration]!;

        if (_recordedDuration != null && totalDuration + dur > _recordedDuration!) break;

        String finalNote;
        int offset = 0;

        if (midi < saxMinNote || midi > saxMaxNote) {
          final chord = i % 8 < 3 ? chordTones['I']! : i % 8 < 6 ? chordTones['IV']! : chordTones['V']!;
          final fallbackPool = [...chord, ...scale];
          final replacement = replaceWithNearestPlayable(baseNote, newOctave, fallbackPool);
          finalNote = replacement.key;
          offset = replacement.value;
        } else {
          finalNote = '$newNote$newOctave';
        }

        result.add('$finalNote ($duration)');
        motif.add('$finalNote ($duration)');
        totalDuration += dur;

        if (offset != 0 && motif.length > 1) {
          motif = motif.map((n) {
            final m = RegExp(r'^([A-G#]+)(\d) \(([^)]+)\)$').firstMatch(n);
            if (m == null) return n;
            final base = m.group(1)!;
            final o = int.parse(m.group(2)!);
            final d = m.group(3)!;
            int newMidi = noteToMidi(base, o) + offset;
            newMidi = newMidi.clamp(saxMinNote, saxMaxNote);
            return '${midiToNote(newMidi)} ($d)';
          }).toList();
        }

        if (motif.length >= 4 && i % 8 == 0 && motifCount < 2) {
          result.addAll(motif);
          motifCount++;
        }
      }
    }

    setState(() {
      noteWidgets = result.map((n) => {
        'text': n,
        'isPlaying': false,
      }).toList();
      extractedText = '🎵 Melody:';
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
                  'HEAR IT. SEE IT. PLAY IT',
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
                onTap: _isRecording ? null : () => startRecordingProcess(),
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
              if (_isRecording)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: stopRecording,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Recording'),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: convertAndStylizeMelodyUsingTheory,
                      child: Image.asset('assets/convertButton.png', width: 100),
                    ),
                    Image.asset('assets/actIcon.png', width: 40),
                    GestureDetector(
                      onTap: playExtractedNotes,
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
