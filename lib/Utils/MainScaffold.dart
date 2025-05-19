import 'package:flutter/material.dart';
import 'package:auris_app/pages/imprPageState.dart';
import 'package:auris_app/pages/melodyPageState.dart';
import 'package:auris_app/pages/transPageState.dart';
import 'package:auris_app/pages/lessonPageState.dart';

import 'midiServicemidiSservice.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    TransPage(),
    LessonsPage(),
    ImprPage(),
    MelodyPage(),
  ];

  final List<String> _icons = [
    'assets/group1.png',
    'assets/group2.png',
    'assets/group3.png',
    'assets/group4.png',
  ];

  bool _midiReady = false;

  @override
  void initState() {
    super.initState();
    _initMidi();
  }

  Future<void> _initMidi() async {
    await MidiService().init(); // ✅ Load MIDI soundfont once
    setState(() {
      _midiReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 360;
    final imageSize = isSmall ? 50.0 : 70.0;
    final logoSize = isSmall ? 60.0 : 90.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _midiReady
          ? IndexedStack(
        index: _currentIndex,
        children: _pages,
      )
          : const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        color: const Color(0xFF2D2D2D),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Image.asset('assets/mainPart.png', width: logoSize),
            for (int i = 0; i < _icons.length; i++)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _currentIndex = i;
                  });
                },
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _currentIndex == i ? 1.0 : 0.4,
                  child: Image.asset(
                    _icons[i],
                    width: imageSize,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
