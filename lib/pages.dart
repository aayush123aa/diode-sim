import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'lab.dart';
import 'physics.dart';
import 'plots.dart';
import 'theme.dart';

// ---------------- 01 Introduction ----------------
class IntroPage extends StatelessWidget {
  final void Function(int) go;
  const IntroPage({super.key, required this.go});
  @override
  Widget build(BuildContext c) {
    Widget feat(String t, String d) => Inset(color: C.stripe, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: ui(13, w: FontWeight.w700)), const SizedBox(height: 4), Text(d, style: ui(12.5, c: C.ink2, h: 1.5))]));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Win('Diode V-I Lab', child: Cols(breakAt: 760, fa: 3, fb: 2, a: [
        Text('Diode V-I Lab', style: ui(30, w: FontWeight.w700, h: 1.15)),
        const SizedBox(height: 4),
        Text('Semiconductor devices · interactive experiment', style: ui(12, c: C.ink3)),
        const SizedBox(height: 14),
        const Para('Build a real breadboard circuit, sweep a 0–30 V supply and watch a diode’s exponential V-I curve appear from your own measurements.'),
        const Para('Switch between silicon, Schottky, germanium, LED and Zener devices, change the series resistor and heat the junction – every reading comes from the Shockley equation, solved live.'),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [Btn('Start the experiment', primary: true, onTap: () => go(2)), Btn('How biasing works', onTap: () => go(1))]),
      ], b: [
        const SizedBox(height: 12),
        Inset(pad: const EdgeInsets.all(6), child: SizedBox(height: 190, child: _Anim(builder: (t) => CustomPaint(painter: JunctionPainter(0, t, 0))))),
        Padding(padding: const EdgeInsets.only(top: 6), child: Text('P-N junction at zero bias', style: ui(12, c: C.ink3), textAlign: TextAlign.center)),
      ])),
      Win('01 · What is a diode?', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        Para('A diode is a two-terminal component that conducts current in one direction only. A semiconductor diode (usually silicon) is a P-N junction: P-type material (rich in holes, +) joined to N-type material (rich in free electrons, −).'),
        Para('At the junction, electrons and holes diffuse across and recombine, leaving a region with no free carriers: the depletion region. Its fixed ions create a built-in barrier (~0.7 V for Si). Applying an external voltage shrinks or widens this barrier, which decides whether the diode conducts.'),
      ])),
      Win('02 · Features', child: LayoutBuilder(builder: (c, bc) {
        final cols = bc.maxWidth > 820 ? 4 : bc.maxWidth > 480 ? 2 : 1;
        final w = (bc.maxWidth - 12 * (cols - 1)) / cols;
        final items = [
          feat('Real breadboard', 'Place parts, run wires, flip the diode. Short circuits and open loops are detected.'),
          feat('Five diode types', 'Si, Schottky, Ge, LED (it lights up!) and a 5.1 V Zener with reverse breakdown.'),
          feat('Live load line', 'See the operating point slide along the curve as you turn the supply knob.'),
          feat('Auto-sweep & fit', 'Log 17 readings in seconds, then extract n and Is from your own data.'),
        ];
        return Wrap(spacing: 12, runSpacing: 12, children: [for (final i in items) SizedBox(width: w, child: i)]);
      })),
      Win('03 · Diode families', child: DataGrid(const ['Type', 'Part', 'Knee', 'Typical use'], const [
        ['Silicon', '1N4007', '≈ 0.7 V', 'Mains rectifiers'],
        ['Schottky', '1N5819', '≈ 0.3 V', 'Switch-mode supplies'],
        ['Germanium', '1N34A', '≈ 0.25 V', 'Radio detectors'],
        ['Red LED', '5 mm', '≈ 1.8 V', 'Indicators, lighting'],
        ['Zener', '1N4733', '0.7 V / 5.1 V rev.', 'Voltage references'],
      ])),
    ]);
  }
}

class _Anim extends StatefulWidget {
  final Widget Function(double t) builder; const _Anim({required this.builder});
  @override
  State<_Anim> createState() => _AnimS();
}
class _AnimS extends State<_Anim> with SingleTickerProviderStateMixin {
  late final ctl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  @override
  void dispose() { ctl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext c) => AnimatedBuilder(animation: ctl, builder: (c, _) => widget.builder(ctl.value));
}

// ---------------- 02 Biasing ----------------
class BiasPage extends StatefulWidget { const BiasPage({super.key}); @override State<BiasPage> createState() => _BiasS(); }
class _BiasS extends State<BiasPage> {
  bool fwd = true; double v = .5;
  @override
  Widget build(BuildContext c) {
    final m = models[0];
    final vd = fwd ? v : -v;
    final i = m.current(vd, 300); // A
    final mA = i * 1000;
    final pts = fwd
        ? [for (double x = 0; x <= .9; x += .005) Offset(x, m.current(x, 300) * 1000)]
        : [for (double x = -10; x <= 0; x += .25) Offset(x, m.current(x, 300) * 1e9)];
    final mark = fwd ? Offset(vd, mA) : Offset(vd, i * 1e9);
    final flow = (mA / 25).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Cols(a: [
        Win('Schematic', child: Inset(pad: const EdgeInsets.all(4), child: SizedBox(height: 230, child: _Anim(builder: (t) => CustomPaint(painter: SchematicPainter(fwd, t, flow)))))),
        Win('Inside the junction', child: Inset(pad: const EdgeInsets.all(6), child: SizedBox(height: 200, child: _Anim(builder: (t) => CustomPaint(painter: JunctionPainter(vd, t, flow)))))),
      ], b: [
        Win('Bias control', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Btn('Forward', selected: fwd, onTap: () => setState(() { fwd = true; v = .6; }))),
            const SizedBox(width: 8),
            Expanded(child: Btn('Reverse', selected: !fwd, onTap: () => setState(() { fwd = false; v = 5; }))),
          ]),
          Caption(fwd ? 'Forward voltage' : 'Reverse voltage'),
          Slider(value: v, min: 0, max: fwd ? .9 : 10, divisions: fwd ? 180 : 100, label: '${v.toStringAsFixed(2)} V', onChanged: (x) => setState(() => v = x)),
          Row(children: [
            Expanded(child: Lcd('${vd.toStringAsFixed(2)} V', label: 'Vd', size: 22)),
            const SizedBox(width: 10),
            Expanded(child: Lcd(fwd ? fmtCur(mA) : '${(i * 1e9).toStringAsFixed(2)} nA', label: 'Id', size: 22)),
          ]),
        ])),
        Win(fwd ? 'Forward V-I curve' : 'Reverse V-I curve', child: SizedBox(height: 320, child: CustomPaint(
            painter: Plot([Series(pts)], fwd ? 0 : -10, fwd ? .9 : 0, fwd ? 0 : -6, fwd ? 30 : 1, 'Vd (V)', fwd ? 'Id (mA)' : 'Id (nA)', mark: mark)))),
      ]),
      Win(fwd ? 'Forward bias' : 'Reverse bias', child: Para(fwd
          ? 'P-side connected to +, N-side to −. The applied field opposes the built-in barrier, so the depletion region narrows. Above the knee voltage (~0.7 V for Si) carriers cross the junction and current rises exponentially – note the dots racing round the circuit. Drag the slider past 0.7 V.'
          : 'P-side connected to −, N-side to +. The depletion region widens and the barrier grows, so only a tiny reverse saturation current (nanoamps) flows. The Zener diode in the lab breaks down at 5.1 V – try it by flipping the diode on the breadboard.')),
    ]);
  }
}

// ---------------- 04 Theory & procedure ----------------
class TheoryPage extends StatelessWidget {
  final void Function(int) go;
  const TheoryPage({super.key, required this.go});
  @override
  Widget build(BuildContext c) {
    Widget eq(String s) => Container(width: double.infinity, margin: const EdgeInsets.symmetric(vertical: 6), padding: const EdgeInsets.all(12), color: C.lcd, child: Text(s, style: mono(15, c: C.lcdInk, w: FontWeight.w600)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Win('04 · Experiment', child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Para('Experiment: V-I characteristics of a semiconductor diode (Si).'),
        Para('Objective: design the circuit, draw the characteristic curve and determine the DC forward resistance.'),
        Para('Equipment: voltmeter / digital multimeter, ammeter, breadboard, diode (1N4007), 1 kΩ resistor, 0–30 V DC supply.'),
      ])),
      Cols(a: [
        Win('Theory', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Para('Shockley ideal diode equation:'),
          eq('I = Is · (e^(Vd / (n·VT)) − 1)'),
          const Para('I = diode current, Is = reverse saturation current, Vd = voltage across the diode, n = ideality factor (1–2), VT = kT/q ≈ 25.85 mV at 300 K.'),
          const Para('DC forward resistance and small-signal resistance:'),
          eq('Rdc = Vd / Id\nrd  = dVd / dId ≈ n·VT / Id'),
          const Para('Temperature: Is grows rapidly with T, so at constant current Vd falls by roughly 2 mV per kelvin. Drag the temperature slider in the lab to see the curve shift.'),
          const Para('Load line: the circuit imposes Vs = Vd + I·R. The diode settles where this straight line crosses its own curve – the Q point.'),
        ])),
      ], b: [
        Win('Procedure', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Para('1. Connect the circuit as shown (supply → 1 kΩ → ammeter → diode, voltmeter across the diode). The “Reference circuit” button does this for you.'),
          Para('2. Increase the supply voltage in steps (0.5 V up to 5 V; use 0.1 V steps near the knee for a smooth curve). Press Record at each step – or use Auto-sweep.'),
          Para('3. Repeat until the supply reaches 5 V (or beyond, up to 30 V).'),
          Para('4. Open the Results page and read off the knee voltage, Rdc, rd and the fitted ideality factor.'),
          Para('5. Extension: flip the diode, swap the type, heat it, or change R – what happens to the curve?'),
        ])),
        Win('Ready?', child: Row(children: [Btn('Open the lab', primary: true, onTap: () => go(2)), const SizedBox(width: 10), Btn('Results', onTap: () => go(4))])),
      ]),
    ]);
  }
}

// ---------------- 05 Results ----------------
class ResultsPage extends StatefulWidget {
  final void Function(int) go;
  const ResultsPage({super.key, required this.go});
  @override
  State<ResultsPage> createState() => _ResS();
}
class _ResS extends State<ResultsPage> {
  String? sel; bool log = false;
  final answers = <int, int>{};
  static const quiz = [
    ['In forward bias the depletion region…', 'narrows', 'widens', 'is unaffected', '0'],
    ['The knee voltage of a silicon diode is about…', '0.2 V', '0.7 V', '1.8 V', '1'],
    ['As forward current rises, Rdc = Vd/Id…', 'rises', 'falls', 'stays constant', '1'],
    ['Why is a series resistor needed?', 'To limit the exponentially rising current', 'To raise the knee voltage', 'To reverse-bias the diode', '0'],
    ['Heating a diode at constant current makes Vd…', 'rise', 'fall slightly', 'jump to 5 V', '1'],
  ];

  @override
  Widget build(BuildContext c) => ValueListenableBuilder<List<Rec>>(valueListenable: records, builder: (c, all, _) {
        final ids = all.map((r) => r.model).toSet().toList();
        final cur = (sel != null && ids.contains(sel)) ? sel : (ids.isEmpty ? null : ids.last);
        final l = all.where((r) => r.model == cur).toList()..sort((a, b) => a.vd.compareTo(b.vd));
        final m = models.firstWhere((e) => e.id == (cur ?? 'si'));
        final fwdPts = l.where((r) => r.vd > 0 && r.id > 0).toList();
        final fit = fitShockley(l);
        double? knee;
        for (int k = 0; k < fwdPts.length; k++) {
          if (fwdPts[k].id >= 1) {
            if (k == 0) { knee = fwdPts[k].vd; } else { final a = fwdPts[k - 1], b = fwdPts[k]; knee = a.vd + (b.vd - a.vd) * (1 - a.id) / (b.id - a.id); }
            break;
          }
        }
        String rd(int k) {
          if (k + 1 >= fwdPts.length) return '—';
          final a = fwdPts[k], b = fwdPts[k + 1];
          return (b.id - a.id) > 0.02 ? ((b.vd - a.vd) / ((b.id - a.id) / 1000)).toStringAsFixed(1) : '—';
        }
        final rows = <List<String>>[];
        for (final r in l) {
          final k = fwdPts.indexOf(r);
          rows.add([r.vs.toStringAsFixed(2), r.vd.toStringAsFixed(3), fmtCur(r.id), r.id > 1e-3 && r.vd > 0 ? (r.vd / (r.id / 1000)).toStringAsFixed(1) : '—', k >= 0 ? rd(k) : '—']);
        }
        final pts = [for (final r in l) Offset(r.vd, r.id)];
        final maxV = l.isEmpty ? 1.0 : max(.2, l.map((e) => e.vd).reduce(max) * 1.08);
        final minV = l.isEmpty ? 0.0 : min(0.0, l.map((e) => e.vd).reduce(min) * 1.08);
        final maxI = l.isEmpty ? 1.0 : max(1.0, l.map((e) => e.id).reduce(max) * 1.1);
        final fitPts = fit == null ? <Offset>[] : [for (double x = max(0.05, minV); x <= maxV; x += maxV / 120) Offset(x, fit.isA * (exp(x / (fit.n * kB * 300 / qe)) - 1) * 1000)];

        Widget stat(String label, String v) => Expanded(child: Lcd(v, label: label, size: 18));
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (l.isEmpty)
            Win('05 · Results', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Para('No readings yet. Open the interactive circuit, build the reference circuit and press Auto-sweep.'),
              Btn('Go to the lab', primary: true, onTap: () => widget.go(2)),
            ]))
          else ...[
            Win('05 · Summary', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(spacing: 8, runSpacing: 8, children: [for (final id in ids) Btn(models.firstWhere((e) => e.id == id).name, compact: true, selected: id == cur, onTap: () => setState(() => sel = id))]),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (c, bc) {
                final s = [
                  stat('KNEE Vd @ 1 mA', knee == null ? '—' : '${knee.toStringAsFixed(3)} V'),
                  stat('FITTED n', fit == null ? '—' : fit.n.toStringAsFixed(2)),
                  stat('FITTED Is', fit == null ? '—' : '${(fit.isA * 1e9).toStringAsFixed(2)} nA'),
                ];
                return bc.maxWidth < 520 ? Column(children: [for (final w in s) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [w]))]) : Row(children: [s[0], const SizedBox(width: 8), s[1], const SizedBox(width: 8), s[2]]);
              }),
              const SizedBox(height: 10),
              Text(fit == null ? 'Need ≥ 3 forward readings above 0.02 mA for the Shockley fit.' : 'Library value for ${m.part}: n = ${m.n}, Is = ${(m.isat * 1e9).toStringAsPrecision(3)} nA (at 300 K).', style: ui(12, c: C.ink3)),
            ])),
            Cols(fa: 6, fb: 5, a: [
              Win('Id vs Vd', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [Btn('Linear', compact: true, selected: !log, onTap: () => setState(() => log = false)), const SizedBox(width: 8), Btn('Log (semilog)', compact: true, selected: log, onTap: () => setState(() => log = true))]),
                const SizedBox(height: 10),
                SizedBox(height: 340, child: CustomPaint(painter: Plot([
                  if (fitPts.isNotEmpty) Series(fitPts, color: C.amber, w: 1.8, dashed: true),
                  Series(pts, color: C.accent, dots: true),
                ], log ? 0 : minV, maxV, log ? 1e-4 : 0, log ? max(10, maxI * 2) : maxI, 'Vd (V)', 'Id (mA)', logY: log))),
                Padding(padding: const EdgeInsets.only(top: 8), child: Text(log ? 'On a log axis the exponential becomes a straight line – its slope gives 1/(n·VT).' : 'Dashed: Shockley fit to your data.', style: ui(12, c: C.ink3))),
              ])),
            ], b: [
              Win('Table · ${l.length} readings', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(spacing: 8, children: [Btn('Copy CSV', compact: true, onTap: () {
                  Clipboard.setData(ClipboardData(text: ['model,R_ohm,T_K,Vs_V,Vd_V,Id_mA', for (final r in all) '${r.model},${r.r.toStringAsFixed(0)},${r.temp.toStringAsFixed(0)},${r.vs},${r.vd.toStringAsFixed(4)},${r.id.toStringAsFixed(5)}'].join('\n')));
                  ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('CSV copied to clipboard')));
                }), Btn('Back to lab', compact: true, onTap: () => widget.go(2))]),
                const SizedBox(height: 10),
                DataGrid(const ['Vs', 'Vd (V)', 'Id', 'Rdc (Ω)', 'rd (Ω)'], rows, maxH: 340),
              ])),
            ]),
            const Win('Observation', child: Para('The current is negligible below the knee (~0.5–0.7 V for Si) and then rises sharply, while Vd stays nearly constant near 0.7 V. The DC resistance therefore falls as current increases, and the small-signal resistance rd falls even faster (rd ≈ n·VT / I).')),
          ],
          Win('Check your understanding', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (int q = 0; q < quiz.length; q++) _quizItem(q),
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('Score: ${answers.entries.where((e) => quiz[e.key][4] == '${e.value}').length} / ${quiz.length}', style: ui(13, w: FontWeight.w700))),
          ])),
        ]);
      });

  Widget _quizItem(int q) {
    final it = quiz[q]; final a = answers[q];
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${q + 1}. ${it[0]}', style: ui(13.5, w: FontWeight.w600)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (int k = 0; k < 3; k++) _ChoiceBtn(it[k + 1], a == k, a == null ? null : (k == int.parse(it[4]) ? true : (a == k ? false : null)), () => setState(() => answers[q] = k)),
      ]),
    ]));
  }
}

class _ChoiceBtn extends StatelessWidget {
  final String label; final bool picked; final bool? verdict; final VoidCallback onTap;
  const _ChoiceBtn(this.label, this.picked, this.verdict, this.onTap);
  @override
  Widget build(BuildContext c) {
    final col = verdict == true ? C.ok : verdict == false ? C.bad : C.lo;
    return GestureDetector(onTap: onTap, child: MouseRegion(cursor: SystemMouseCursors.click, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: verdict == true ? C.okWash : picked ? const Color(0xFFFBE3E1) : Colors.white, border: Border.all(color: col, width: verdict == null ? 1 : 2), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: ui(13)),
    )));
  }
}
