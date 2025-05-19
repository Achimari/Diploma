import 'package:flutter_midi_pro/flutter_midi_pro.dart';

class MidiService {
  // Singleton instance
  static final MidiService _instance = MidiService._internal();

  // Accessor
  factory MidiService() => _instance;

  late final MidiPro midiPro;
  int? soundFontId;

  MidiService._internal() {
    midiPro = MidiPro();
  }

  Future<void> init() async {
    if (soundFontId != null) return;

    soundFontId = await midiPro.loadSoundfont(
      path: 'assets/FluidR3_GM.sf2',
      bank: 0,
      program: 0,
    );

    await midiPro.selectInstrument(
      sfId: soundFontId!,
      channel: 0,
      bank: 0,
      program: 0,
    );
  }
}
