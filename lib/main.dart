import 'package:flutter/material.dart';
import 'lab.dart';
import 'pages.dart';
import 'theme.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'Diode V-I Lab',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: C.accent, brightness: Brightness.light).copyWith(primary: C.accent),
          scaffoldBackgroundColor: C.desk,
          sliderTheme: SliderThemeData(trackHeight: 6, activeTrackColor: C.accent, inactiveTrackColor: C.lo.withValues(alpha: .45), thumbColor: Colors.white,
              overlayColor: C.accent.withValues(alpha: .15), thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 2), trackShape: const RoundedRectSliderTrackShape()),
          snackBarTheme: SnackBarThemeData(backgroundColor: C.ink, contentTextStyle: ui(13, c: Colors.white), behavior: SnackBarBehavior.floating),
        ),
        home: const Shell(),
      );
}

class Shell extends StatefulWidget { const Shell({super.key}); @override State<Shell> createState() => _ShellS(); }
class _ShellS extends State<Shell> {
  int i = 0;
  static const names = ['Intro', 'Biasing', 'Lab', 'Theory', 'Results'];
  void go(int k) => setState(() => i = k.clamp(0, 4));

  Widget menuItem(int k) => GestureDetector(
        onTap: () => go(k),
        child: MouseRegion(cursor: SystemMouseCursors.click, child: Container(
          alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 12),
          color: k == i ? C.accent : Colors.transparent,
          child: Text(names[k], style: ui(13, w: FontWeight.w600, c: k == i ? Colors.white : C.ink, h: 1)),
        )),
      );

  @override
  Widget build(BuildContext c) {
    final narrow = isNarrow(c);
    final pages = <Widget>[
      IntroPage(go: go), const BiasPage(), LabPage(onResults: () => go(4)), TheoryPage(go: go), ResultsPage(go: go),
    ];
    return Scaffold(
      body: SafeArea(child: Column(children: [
        // menu bar
        Container(
          height: 32,
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Color(0xFFD2D2D2)]), border: Border(bottom: BorderSide(color: C.edge))),
          child: Row(children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(narrow ? 'Diode Lab' : 'Diode V-I Lab', style: ui(14, w: FontWeight.w800, h: 1))),
            Expanded(child: ListView(scrollDirection: Axis.horizontal, children: [for (int k = 0; k < 5; k++) menuItem(k)])),
            if (!narrow) const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Clock()),
          ]),
        ),
        Expanded(child: IndexedStack(index: i, children: [
          for (int k = 0; k < 5; k++)
            TickerMode(enabled: k == i, child: SingleChildScrollView(
              key: PageStorageKey('p$k'),
              padding: EdgeInsets.fromLTRB(narrow ? 10 : 24, 18, narrow ? 10 : 24, 24),
              child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1120), child: pages[k])),
            )),
        ])),
        // status bar
        Container(
          padding: EdgeInsets.symmetric(horizontal: narrow ? 8 : 16, vertical: 8),
          decoration: const BoxDecoration(color: C.chrome, border: Border(top: BorderSide(color: C.edge))),
          child: Row(children: [
            Btn('◀ Back', compact: true, onTap: i > 0 ? () => go(i - 1) : null),
            Expanded(child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (int k = 0; k < 5; k++) GestureDetector(onTap: () => go(k), child: Container(margin: const EdgeInsets.all(4), width: 10, height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: k == i ? C.accent : C.chrome2, border: Border.all(color: C.edge, width: .8)))),
              if (!narrow) Padding(padding: const EdgeInsets.only(left: 10), child: Text('Step ${i + 1} of 5 · ${names[i]}', style: ui(12, c: C.ink2))),
            ]))),
            Btn('Next ▶', compact: true, primary: true, onTap: i < 4 ? () => go(i + 1) : null),
          ]),
        ),
      ])),
    );
  }
}
