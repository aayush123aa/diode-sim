import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const App());

// ---------- Physics model (1N4007-like, Shockley equation) ----------
const vt = 0.02585, isat = 2.5e-9, nf = 1.9, rOhm = 1000.0;
double diodeI(double v) => isat * (exp(v / (nf * vt)) - 1);
double solveVd(double vs) {
  double lo = 0, hi = vs;
  for (int i = 0; i < 60; i++) {
    final m = (lo + hi) / 2;
    if (vs - m - rOhm * diodeI(m) > 0) { lo = m; } else { hi = m; }
  }
  return (lo + hi) / 2;
}

class Rec { final double vs, vd, id; Rec(this.vs, this.vd, this.id); } // id in mA
final records = ValueNotifier<List<Rec>>([]);

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'Diode V-I Lab',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF3F51B5), useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFF5F7FB), fontFamilyFallback: const ['Roboto', 'Noto Sans', 'DejaVu Sans', 'Arial']),
        home: const Shell(),
      );
}

// ---------- Shell: 5 linear pages ----------
class Shell extends StatefulWidget { const Shell({super.key}); @override State<Shell> createState() => _ShellS(); }
class _ShellS extends State<Shell> {
  final pc = PageController(); int i = 0;
  static const titles = ['1. Introduction', '2. Biasing', '3. Interactive Circuit', '4. Procedure & Theory', '5. Results'];
  void go(int d) { setState(() => i += d); pc.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut); }
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(centerTitle: false, title: Text(titles[i], overflow: TextOverflow.ellipsis)),
        body: PageView(controller: pc, physics: const NeverScrollableScrollPhysics(), children: const [
          Pg(child: Page1()), Pg(child: Page2()), Pg(child: Page3()), Pg(child: Page4()), Pg(child: Page5()),
        ]),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            OutlinedButton.icon(onPressed: i > 0 ? () => go(-1) : null, icon: const Icon(Icons.arrow_back), label: const Text('Back')),
            Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (int k = 0; k < 5; k++) Container(margin: const EdgeInsets.all(3), width: 10, height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: k == i ? Colors.indigo : Colors.grey.shade300))])),
            FilledButton.icon(onPressed: i < 4 ? () => go(1) : null, icon: const Icon(Icons.arrow_forward), label: const Text('Next')),
          ]),
        ),
      );
}

class Pg extends StatelessWidget {
  final Widget child; const Pg({super.key, required this.child});
  @override
  Widget build(BuildContext c) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: child)));
}

Widget h(String s) => Padding(padding: const EdgeInsets.only(top: 28, bottom: 14), child: Text(s, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.25, color: Color(0xFF1A237E))));
Widget p(String s) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(s, style: const TextStyle(fontSize: 16, height: 1.7, letterSpacing: 0.2, color: Color(0xFF37474F))));
Widget cap(String s) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(s, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: .4, color: Color(0xFF5C6BC0))));
String fmt(double v) => v.abs() < 1e-9 ? '0' : v.abs() >= 10 ? v.toStringAsFixed(0) : v.abs() >= 1 ? v.toStringAsFixed(1) : v.abs() >= 0.01 ? v.toStringAsFixed(2) : v.toStringAsExponential(0);
Widget card(double hgt, CustomPainter pt) => Card(elevation: 0, margin: const EdgeInsets.symmetric(vertical: 6), color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE0E4EF))),
    child: Padding(padding: const EdgeInsets.all(12), child: ClipRect(child: SizedBox(height: hgt, width: double.infinity, child: CustomPaint(painter: pt)))));

// ---------- Page 1 ----------
class Page1 extends StatelessWidget {
  const Page1({super.key});
  @override
  Widget build(BuildContext c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        h('Introduction to Semiconductor Diodes'),
        card(220, StructPainter(0)),
        p('A diode is a two-terminal component that conducts current in one direction only. A semiconductor diode (usually silicon) is a P-N junction: P-type material (rich in holes, +) joined to N-type material (rich in free electrons, −).'),
        p('At the junction, electrons and holes diffuse across and recombine, leaving a region with no free carriers: the depletion region. Its fixed ions create a built-in barrier (~0.7 V for Si). Applying an external voltage shrinks or widens this barrier, which decides whether the diode conducts.'),
      ]);
}

// ---------- Page 2 ----------
class Page2 extends StatefulWidget { const Page2({super.key}); @override State<Page2> createState() => _P2(); }
class _P2 extends State<Page2> {
  bool fwd = true;
  @override
  Widget build(BuildContext c) {
    final pts = fwd
        ? [for (double v = 0; v <= 0.9 && diodeI(v) * 1000 <= 30; v += 0.005) Offset(v, diodeI(v) * 1000)]
        : [for (double v = -10; v <= 0; v += 0.5) Offset(v, -0.0005)];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      h('Forward and Reverse Biasing'),
      Row(children: [
        const Text('Reverse', style: TextStyle(fontSize: 16)),
        Switch(value: fwd, onChanged: (v) => setState(() => fwd = v)),
        const Text('Forward', style: TextStyle(fontSize: 16)),
      ]),
      LayoutBuilder(builder: (c, bc) {
        final w = bc.maxWidth > 700;
        final items = [
          Expanded(flex: w ? 1 : 0, child: Column(children: [
            cap('Circuit'), card(220, CircuitPainter(fwd)),
            cap('Internal structure'), card(160, StructPainter(fwd ? 1 : 2))])),
          Expanded(flex: w ? 1 : 0, child: Column(children: [
            cap(fwd ? 'Forward V-I curve' : 'Reverse V-I curve'),
            card(400, Plot(pts, fwd ? 0 : -10, fwd ? 0.8 : 0, fwd ? 0 : -0.002, fwd ? 30 : 0.002,
                fwd ? 'V (volts)' : 'V (volts, reverse)', 'I (mA)'))])),
        ];
        return w ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: items) : Column(children: items.map((e) => e.child).toList());
      }),
      p(fwd
          ? 'FORWARD BIAS: P-side connected to +, N-side to −. The applied field opposes the built-in barrier, so the depletion region narrows. Above the knee voltage (~0.7 V for Si) carriers cross the junction and current rises exponentially.'
          : 'REVERSE BIAS: P-side connected to −, N-side to +. The depletion region widens and the barrier grows, so only a tiny reverse saturation current (nA–µA) flows until breakdown at a very high voltage.'),
    ]);
  }
}

// ---------- Page 3: interactive circuit (real breadboard) ----------
const rowY = [90.0, 108.0, 126.0, 144.0, 162.0, 202.0, 220.0, 238.0, 256.0, 274.0];
const terms = {'T:S+': Offset(110, 350), 'T:S-': Offset(170, 350), 'T:A+': Offset(430, 350), 'T:A-': Offset(490, 350), 'T:V+': Offset(710, 350), 'T:V-': Offset(770, 350)};
Offset hole(int c, int r) => Offset(70 + c * 28.0, rowY[r]);
Offset kpos(String k) {
  final s = k.split(':');
  if (s[0] == 'H') return hole(int.parse(s[1]), int.parse(s[2]));
  if (s[0] == 'R') return Offset(70 + int.parse(s[1]) * 28.0, s[2] == 'p' ? 30 : 48);
  return terms[k]!;
}
String node(String k) {
  final s = k.split(':');
  if (s[0] == 'H') return 'h${s[1]}${int.parse(s[2]) < 5 ? 't' : 'b'}';   // 5 holes per column strip
  if (s[0] == 'R') return 'r${s[2]}';                                        // whole power rail
  return k;
}
final allKeys = <String>[
  for (int c = 0; c < 30; c++) for (int r = 0; r < 10; r++) 'H:$c:$r',
  for (int c = 0; c < 30; c++) ...['R:$c:p', 'R:$c:n'],
  ...terms.keys,
];
Color wireColor(String a, String b, int n) {
  final t = a + b;
  if (t.contains('+')) return Colors.red.shade700;
  if (t.contains('T:') && t.contains('-')) return Colors.black87;
  return [Colors.blue.shade600, Colors.green.shade700, Colors.orange.shade800, Colors.purple.shade400][n % 4];
}

class Part { String type; int col, row; bool flip; Part(this.type, this.col, this.row, [this.flip = false]); }
class Wire { String a, b; Color c; Wire(this.a, this.b, this.c); }
class Sim { final String msg; final bool ok; final double? iMa, vv; Sim(this.msg, this.ok, [this.iMa, this.vv]); }

Sim simulate(List<Part> parts, List<Wire> wires, double vs) {
  final uf = <String, String>{};
  String f(String x) { uf.putIfAbsent(x, () => x); while (uf[x] != x) { uf[x] = uf[uf[x]!]!; x = uf[x]!; } return x; }
  for (final w in wires) { uf[f(node(w.a))] = f(node(w.b)); }
  if (f('T:S+') == f('T:S-')) return Sim('Short circuit across the supply – remove a wire!', false);
  final edges = <List<dynamic>>[];
  for (final p in parts) {
    final a = f(node('H:${p.col}:${p.row}')), b = f(node('H:${p.col + 4}:${p.row}'));
    if (a == b) continue;
    if (p.type == 'R') { edges.add(['R', a, b]); } else { edges.add(['D', p.flip ? b : a, p.flip ? a : b]); }
  }
  final am = f('T:A+'), an = f('T:A-');
  if (am != an) edges.add(['A', am, an]);
  final goal = f('T:S-');
  List<List<dynamic>>? dfs(String at, Set<int> used) {
    if (at == goal) return [];
    for (int i = 0; i < edges.length; i++) {
      if (used.contains(i)) continue;
      final e = edges[i]; String nx; bool fw;
      if (e[1] == at) { nx = e[2]; fw = true; } else if (e[2] == at) { nx = e[1]; fw = false; } else { continue; }
      final r = dfs(nx, {...used, i});
      if (r != null) return [[e[0], fw, nx], ...r];
    }
    return null;
  }
  final path = dfs(f('T:S+'), {});
  if (path == null) return Sim('Open circuit – no complete path from supply + to supply −. Check your wires and parts.', false);
  final hasR = path.any((s) => s[0] == 'R');
  final ds = path.where((s) => s[0] == 'D').toList();
  final fwd = ds.isEmpty || ds.first[1] == true;
  if (!hasR && fwd) return Sim('No series resistor in the loop – a forward diode would draw unlimited current!', false);
  double vd = 0, i = 0;
  if (hasR && fwd) { if (ds.isEmpty) { i = vs / rOhm; } else { vd = solveVd(vs); i = (vs - vd) / rOhm; } }
  final pot = <String, double>{f('T:S+'): vs};
  double cur = vs;
  for (final s in path) {
    if (s[0] == 'R') { cur -= i * rOhm; } else if (s[0] == 'D') { cur = fwd ? cur - vd : 0; }
    pot[s[2] as String] = cur.abs() < 1e-9 ? 0 : cur;
  }
  final aStep = path.where((s) => s[0] == 'A').toList();
  final iMa = aStep.isEmpty ? null : (aStep.first[1] == true ? i : -i) * 1000;
  final vp = pot[f('T:V+')], vn = pot[f('T:V-')];
  final vv = (vp == null || vn == null) ? null : vp - vn;
  var msg = 'Circuit closed – diode is ${fwd ? 'forward' : 'reverse'} biased.';
  if (iMa == null) { msg += ' Put the ammeter in series.'; } else if (vv == null) { msg += ' Connect the voltmeter across the diode.'; }
  return Sim(msg, true, iMa, vv);
}

class Page3 extends StatefulWidget { const Page3({super.key}); @override State<Page3> createState() => _P3(); }
class _P3 extends State<Page3> {
  final canvasKey = GlobalKey();
  final parts = <Part>[]; final wires = <Wire>[];
  String? pending; double vs = 0;

  String? hit(Offset p) {
    String? best; double bd = 12;
    for (final k in allKeys) { final d = (kpos(k) - p).distance; if (d < bd) { bd = d; best = k; } }
    return best;
  }
  Part? partAt(Offset p) {
    for (final q in parts) {
      final m = (hole(q.col, q.row) + hole(q.col + 4, q.row)) / 2;
      if ((p.dx - m.dx).abs() < 34 && (p.dy - m.dy).abs() < 14) return q;
    }
    return null;
  }
  void tap(Offset p) {
    final q = partAt(p);
    if (q != null) { if (q.type == 'D') setState(() => q.flip = !q.flip); return; }
    final k = hit(p);
    setState(() {
      if (k == null || k == pending) { pending = null; }
      else if (pending == null) { pending = k; }
      else { wires.add(Wire(pending!, k, wireColor(pending!, k, wires.length))); pending = null; }
    });
  }
  void remove(Offset p) {
    final q = partAt(p);
    setState(() {
      if (q != null) { parts.remove(q); return; }
      final k = hit(p);
      if (k != null) wires.removeWhere((w) => w.a == k || w.b == k);
    });
  }
  void drop(String type, Offset g) {
    final p = (canvasKey.currentContext!.findRenderObject() as RenderBox).globalToLocal(g);
    int bc = -1, br = 0; double bd = 40;
    for (int c = 0; c <= 25; c++) { for (int r = 0; r < 10; r++) { final d = (hole(c, r) - p).distance; if (d < bd) { bd = d; bc = c; br = r; } } }
    if (bc < 0) return;
    if (parts.any((q) => q.type != type && q.row == br && (q.col - bc).abs() < 5)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Those holes are already occupied.'))); return;
    }
    setState(() { parts.removeWhere((q) => q.type == type); parts.add(Part(type, bc, br)); });
  }
  void loadReference() => setState(() {
        parts..clear()..addAll([Part('R', 3, 0), Part('D', 14, 0)]);
        wires.clear(); pending = null;
        for (final w in [['T:S+', 'H:3:1'], ['H:7:1', 'T:A+'], ['T:A-', 'H:14:1'], ['H:18:1', 'T:S-'], ['T:V+', 'H:14:2'], ['T:V-', 'H:18:2']]) {
          wires.add(Wire(w[0], w[1], wireColor(w[0], w[1], wires.length)));
        }
      });

  Widget tray(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF9FA8DA))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(t == 'R' ? Icons.horizontal_rule : Icons.play_arrow, color: Colors.indigo), const SizedBox(width: 8),
          Text(t == 'R' ? '1 kΩ resistor' : 'Diode 1N4007', style: const TextStyle(fontSize: 14)),
        ]));
  Widget drag(String t) => Draggable<String>(
        data: t, dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Material(color: Colors.transparent, child: Transform.translate(offset: const Offset(-20, -20), child: tray(t))),
        childWhenDragging: Opacity(opacity: .4, child: tray(t)), child: tray(t));

  @override
  Widget build(BuildContext c) {
    final s = simulate(parts, wires, vs);
    final canRec = s.ok && s.iMa != null && s.vv != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      h('Interactive Circuit'),
      p('Build the reference circuit: supply (+) → 1 kΩ resistor → ammeter → diode anode, diode cathode → supply (−), with the voltmeter across the diode. Drag the parts onto the breadboard, then tap a terminal or hole and tap a second one to run a wire. Tap the diode to flip it. Long-press a part or a wire end to remove it.'),
      Card(elevation: 0, color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE0E4EF))),
          child: Padding(padding: const EdgeInsets.all(8), child: FittedBox(fit: BoxFit.scaleDown, child: DragTarget<String>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (d) => drop(d.data, d.offset),
            builder: (c, a, b) => SizedBox(key: canvasKey, width: 940, height: 590, child: GestureDetector(
              onTapUp: (d) => tap(d.localPosition),
              onLongPressStart: (d) => remove(d.localPosition),
              child: CustomPaint(painter: BoardPainter(parts, wires, pending, vs, s)))),
          )))),
      const SizedBox(height: 12),
      Container(width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: s.ok ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [Icon(s.ok ? Icons.check_circle : Icons.info, color: s.ok ? Colors.green : Colors.orange), const SizedBox(width: 10), Expanded(child: Text(s.msg, style: const TextStyle(fontSize: 14, height: 1.4)))])),
      cap('Parts (drag onto the breadboard)'),
      Wrap(spacing: 12, runSpacing: 12, children: [drag('R'), drag('D')]),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 12, children: [
        OutlinedButton.icon(onPressed: loadReference, icon: const Icon(Icons.lightbulb_outline), label: const Text('Show reference circuit')),
        OutlinedButton(onPressed: () => setState(() { wires.clear(); pending = null; }), child: const Text('Clear wires')),
        OutlinedButton(onPressed: () => setState(() { wires.clear(); parts.clear(); pending = null; }), child: const Text('Clear all')),
      ]),
      cap('Supply voltage'),
      Row(children: [Expanded(child: Slider(value: vs, min: 0, max: 30, divisions: 300, label: '${vs.toStringAsFixed(1)} V', onChanged: (v) => setState(() => vs = v))),
        SizedBox(width: 90, child: Text('${vs.toStringAsFixed(1)} V', style: const TextStyle(fontSize: 18)))]),
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        FilledButton.icon(
          onPressed: canRec ? () {
            final l = [...records.value]..removeWhere((r) => (r.vs - vs).abs() < 1e-6);
            l.add(Rec(vs, s.vv!, s.iMa!)); l.sort((a, b) => a.vs.compareTo(b.vs));
            setState(() => records.value = l);
          } : null,
          icon: const Icon(Icons.fiber_manual_record), label: const Text('Record')),
        OutlinedButton(onPressed: () => setState(() => records.value = []), child: const Text('Clear table')),
        FilledButton.icon(
          onPressed: records.value.length >= 5 ? () => showDialog(context: context, builder: (_) => GraphDialog(records.value)) : null,
          icon: const Icon(Icons.show_chart), label: const Text('Graph')),
      ]),
      if (records.value.length < 5) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Record at least 5 readings to enable the graph (${records.value.length}/5).', style: const TextStyle(color: Colors.grey))),
      const SizedBox(height: 8),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columnSpacing: 36,
        columns: const [DataColumn(label: Text('V source (V)')), DataColumn(label: Text('Vd (V)')), DataColumn(label: Text('Id (mA)'))],
        rows: [for (final r in records.value) DataRow(cells: [DataCell(Text(r.vs.toStringAsFixed(1))), DataCell(Text(r.vd.toStringAsFixed(3))), DataCell(Text(r.id.toStringAsFixed(3)))])],
      )),
    ]);
  }
}

class BoardPainter extends CustomPainter {
  final List<Part> parts; final List<Wire> wires; final String? pending; final double vs; final Sim sim;
  BoardPainter(this.parts, this.wires, this.pending, this.vs, this.sim);

  void inst(Canvas c, Rect r, String title, String val) {
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(12)), Paint()..color = const Color(0xFF37474F));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.left + 25, r.top + 65, r.width - 50, 60), const Radius.circular(6)), Paint()..color = const Color(0xFF0B1F14));
    txt(c, val, Offset(r.center.dx, r.top + 95), fs: 28, col: const Color(0xFF69F0AE), center: true);
    txt(c, title, Offset(r.center.dx, r.bottom - 45), fs: 13, col: Colors.white, center: true);
  }
  void part(Canvas c, Part q) {
    final a = hole(q.col, q.row), b = hole(q.col + 4, q.row), m = (a + b) / 2;
    c.drawLine(a, b, Paint()..color = const Color(0xFFB0BEC5)..strokeWidth = 3);
    if (q.type == 'R') {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: m, width: 56, height: 18), const Radius.circular(8)), Paint()..color = const Color(0xFFE6C48F));
      final bands = [[-16.0, const Color(0xFF6D4C41)], [-8.0, Colors.black], [0.0, Colors.red], [14.0, const Color(0xFFFFC107)]];
      for (final bd in bands) { c.drawRect(Rect.fromCenter(center: m + Offset(bd[0] as double, 0), width: 4, height: 18), Paint()..color = bd[1] as Color); }
    } else {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: m, width: 60, height: 16), const Radius.circular(3)), Paint()..color = const Color(0xFF212121));
      final kx = q.flip ? -24.0 : 24.0;
      c.drawRect(Rect.fromCenter(center: m + Offset(kx, 0), width: 7, height: 16), Paint()..color = const Color(0xFFCFD8DC));
      txt(c, '1N4007', m + Offset(q.flip ? 4 : -4, 0), fs: 8, col: Colors.white, center: true);
      txt(c, q.flip ? 'K   A' : 'A   K', m + const Offset(0, 20), fs: 10, col: Colors.black54, center: true);
    }
    for (final e in [a, b]) { c.drawCircle(e, 3.5, Paint()..color = const Color(0xFF90A4AE)); }
  }
  @override
  void paint(Canvas c, Size s) {
    const board = Rect.fromLTWH(10, 10, 920, 290);
    c.drawRRect(RRect.fromRectAndRadius(board, const Radius.circular(12)), Paint()..color = const Color(0xFFF4F0E6));
    c.drawRRect(RRect.fromRectAndRadius(board, const Radius.circular(12)), Paint()..style = PaintingStyle.stroke..color = const Color(0xFFBDB6A3)..strokeWidth = 2);
    c.drawRect(const Rect.fromLTWH(40, 177, 860, 10), Paint()..color = const Color(0xFFD9D3C0));
    c.drawLine(const Offset(50, 21), const Offset(890, 21), Paint()..color = Colors.red.shade300..strokeWidth = 2);
    c.drawLine(const Offset(50, 58), const Offset(890, 58), Paint()..color = Colors.blue.shade300..strokeWidth = 2);
    final hp = Paint()..color = const Color(0xFF455A64);
    for (int col = 0; col < 30; col++) {
      for (int r = 0; r < 10; r++) { c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: hole(col, r), width: 8, height: 8), const Radius.circular(2)), hp); }
      for (final y in [30.0, 48.0]) { c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(70 + col * 28.0, y), width: 8, height: 8), const Radius.circular(2)), hp); }
      if (col % 5 == 0) txt(c, '${col + 1}', Offset(70 + col * 28.0, 74), fs: 9, col: Colors.black54, center: true);
    }
    for (int r = 0; r < 10; r++) { txt(c, 'abcdefghij'[r], Offset(46, rowY[r]), fs: 10, col: Colors.black54, center: true); }
    txt(c, '+', const Offset(32, 30), fs: 14, col: Colors.red, center: true);
    txt(c, '−', const Offset(32, 48), fs: 14, col: Colors.blue, center: true);

    inst(c, const Rect.fromLTWH(30, 330, 290, 240), '0–30 V DC POWER SUPPLY', '${vs.toStringAsFixed(1)} V');
    inst(c, const Rect.fromLTWH(350, 330, 250, 240), 'AMMETER (mA)', sim.ok && sim.iMa != null ? sim.iMa!.toStringAsFixed(2) : '— —');
    inst(c, const Rect.fromLTWH(630, 330, 250, 240), 'DIGITAL MULTIMETER (V)', sim.ok && sim.vv != null ? sim.vv!.toStringAsFixed(3) : '— —');
    for (final e in terms.entries) {
      final plus = e.key.endsWith('+');
      c.drawCircle(e.value, 11, Paint()..color = plus ? Colors.red.shade700 : Colors.black);
      c.drawCircle(e.value, 11, Paint()..style = PaintingStyle.stroke..color = Colors.white..strokeWidth = 2);
      txt(c, plus ? '+' : '−', e.value + const Offset(0, 25), fs: 15, col: Colors.white, center: true);
    }
    for (final q in parts) { part(c, q); }
    for (final w in wires) {
      final a = kpos(w.a), b = kpos(w.b), mid = (a + b) / 2;
      final path = Path()..moveTo(a.dx, a.dy)..quadraticBezierTo(mid.dx, mid.dy - 18 - (a - b).distance * .12, b.dx, b.dy);
      c.drawPath(path.shift(const Offset(2, 3)), Paint()..style = PaintingStyle.stroke..color = Colors.black26..strokeWidth = 6..strokeCap = StrokeCap.round);
      c.drawPath(path, Paint()..style = PaintingStyle.stroke..color = w.c..strokeWidth = 4.5..strokeCap = StrokeCap.round);
      for (final e in [a, b]) { c.drawCircle(e, 5, Paint()..color = w.c); }
    }
    if (pending != null) c.drawCircle(kpos(pending!), 13, Paint()..style = PaintingStyle.stroke..color = Colors.amber..strokeWidth = 3);
  }
  @override
  bool shouldRepaint(covariant BoardPainter o) => true;
}

class GraphDialog extends StatelessWidget {
  final List<Rec> r; const GraphDialog(this.r, {super.key});
  @override
  Widget build(BuildContext c) {
    final pts = [const Offset(0, 0), for (final x in r) Offset(x.vd, x.id)];
    final mx = pts.map((e) => e.dx).reduce(max), my = pts.map((e) => e.dy).reduce(max);
    return Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 700, maxHeight: 560), child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      Row(children: [const Expanded(child: Text('Diode V-I Characteristic (Id vs Vd)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), IconButton(onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close))]),
      Expanded(child: CustomPaint(size: Size.infinite, painter: Plot(pts, 0, (mx * 1.1).clamp(0.1, 2), 0, (my * 1.1).clamp(0.1, 100), 'Vd (V)', 'Id (mA)', dots: true))),
    ]))));
  }
}

// ---------- Pages 4 & 5 ----------
class Page4 extends StatelessWidget {
  const Page4({super.key});
  @override
  Widget build(BuildContext c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        h('Experiment: V-I Characteristics of Semiconductor Diode (Si)'),
        p('Objective: Design the circuit, draw the characteristic curve and determine the DC forward resistance.'),
        p('Equipment: Voltmeter / digital multimeter, ammeter, breadboard, diode (1N4007), 1 kΩ resistor, 0–30 V DC supply.'),
        h('Theory'),
        p('Shockley ideal diode equation:   I = Is · (e^(Vd / (n·VT)) − 1)'),
        p('I = diode current, Is = reverse saturation current, Vd = voltage across the diode, n = ideality factor (1–2), VT = kT/q ≈ 25.85 mV at 300 K (k = Boltzmann constant, T = absolute temperature, q = electron charge).'),
        p('DC forward resistance = Vd / Id (ratio of DC voltage across the diode to the resulting DC current).'),
        h('Procedure'),
        p('1. Connect the circuit as shown (supply → 1 kΩ → ammeter → diode, voltmeter across the diode).\n2. Increase the supply voltage in steps (0.5 V up to 5 V; use 0.1 V steps near the knee for a smooth curve). Measure Id and Vd and record them.\n3. Repeat until the supply reaches 5 V (or beyond, up to 30 V).\n4. Plot Id versus Vd for the silicon diode.'),
      ]);
}

class Page5 extends StatelessWidget {
  const Page5({super.key});
  @override
  Widget build(BuildContext c) => ValueListenableBuilder<List<Rec>>(
        valueListenable: records,
        builder: (c, l, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          h('Results & DC Forward Resistance'),
          if (l.isEmpty) p('No readings yet. Go back to the interactive circuit (page 3) and record some data.')
          else ...[
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columnSpacing: 36, 
              columns: const [DataColumn(label: Text('V source (V)')), DataColumn(label: Text('Vd (V)')), DataColumn(label: Text('Id (mA)')), DataColumn(label: Text('Rdc = Vd/Id (Ω)'))],
              rows: [for (final r in l) DataRow(cells: [DataCell(Text(r.vs.toStringAsFixed(1))), DataCell(Text(r.vd.toStringAsFixed(3))), DataCell(Text(r.id.toStringAsFixed(3))),
                DataCell(Text(r.id > 1e-6 ? (r.vd / (r.id / 1000)).toStringAsFixed(1) : '—'))])])),
            const SizedBox(height: 12),
            card(380, Plot([const Offset(0, 0), for (final r in l) Offset(r.vd, r.id)], 0, 1, 0, max(1, l.map((e) => e.id).reduce(max) * 1.1), 'Vd (V)', 'Id (mA)', dots: true)),
          ],
          p('Observation: the current is negligible below the knee (~0.5–0.7 V for Si) and then rises sharply, while Vd stays nearly constant near 0.7 V. The DC resistance therefore falls as current increases.'),
        ]),
      );
}

// ---------- Painters ----------
void txt(Canvas c, String s, Offset o, {double fs = 11, Color col = Colors.black87, bool center = false}) {
  final t = TextPainter(text: TextSpan(text: s, style: TextStyle(fontSize: fs, color: col)), textDirection: TextDirection.ltr)..layout();
  c.drawText(t, center ? o - Offset(t.width / 2, t.height / 2) : o);
}
extension on Canvas { void drawText(TextPainter t, Offset o) => t.paint(this, o); }

class Plot extends CustomPainter {
  final List<Offset> pts; final double x0, x1, y0, y1; final String xl, yl; final bool dots;
  Plot(this.pts, this.x0, this.x1, this.y0, this.y1, this.xl, this.yl, {this.dots = false});
  @override
  void paint(Canvas c, Size s) {
    const l = 62.0, b = 40.0, t = 28.0, r = 24.0;
    final w = s.width - l - r, hh = s.height - b - t;
    Offset m(Offset p) => Offset(l + (p.dx - x0) / (x1 - x0) * w, t + hh - (p.dy - y0) / (y1 - y0) * hh);
    final grid = Paint()..color = Colors.grey.shade300, ax = Paint()..color = Colors.black87..strokeWidth = 1.5;
    for (int i = 0; i <= 5; i++) {
      final x = l + w * i / 5, y = t + hh * i / 5;
      c.drawLine(Offset(x, t), Offset(x, t + hh), grid); c.drawLine(Offset(l, y), Offset(l + w, y), grid);
      txt(c, fmt(x0 + (x1 - x0) * i / 5), Offset(x, t + hh + 12), center: true);
      txt(c, fmt(y1 - (y1 - y0) * i / 5), Offset(6, y - 6));
    }
    final o = m(Offset(x0 <= 0 && x1 >= 0 ? 0 : x0, y0 <= 0 && y1 >= 0 ? 0 : y0));
    c.drawLine(Offset(l, o.dy), Offset(l + w, o.dy), ax); c.drawLine(Offset(o.dx, t), Offset(o.dx, t + hh), ax);
    txt(c, xl, Offset(l + w / 2 - 30, s.height - 16), fs: 12); txt(c, yl, const Offset(6, 4), fs: 12);
    c.save(); c.clipRect(Rect.fromLTWH(l, t, w, hh)); final path = Path(); bool f = true;
    for (final p in pts) { final q = m(p); if (f) { path.moveTo(q.dx, q.dy); f = false; } else { path.lineTo(q.dx, q.dy); } }
    c.drawPath(path, Paint()..color = Colors.indigo..strokeWidth = 2.5..style = PaintingStyle.stroke);
    if (dots) for (final p in pts) { c.drawCircle(m(p), 4, Paint()..color = Colors.red); }
    c.restore();
  }
  @override
  bool shouldRepaint(covariant Plot o) => true;
}

// mode: 0 neutral, 1 forward, 2 reverse
class StructPainter extends CustomPainter {
  final int mode; StructPainter(this.mode);
  @override
  void paint(Canvas c, Size s) {
    final w = s.width - 40, top = 20.0, hh = s.height - 70, x = 20.0;
    final dw = w * (mode == 1 ? .08 : mode == 2 ? .35 : .18), mid = x + w / 2;
    c.drawRect(Rect.fromLTWH(x, top, w / 2 - dw / 2, hh), Paint()..color = Colors.red.shade100);
    c.drawRect(Rect.fromLTWH(mid + dw / 2, top, w / 2 - dw / 2, hh), Paint()..color = Colors.blue.shade100);
    c.drawRect(Rect.fromLTWH(mid - dw / 2, top, dw, hh), Paint()..color = Colors.grey.shade300);
    final rnd = Random(3);
    for (int i = 0; i < 14; i++) {
      final py = top + 12 + rnd.nextDouble() * (hh - 24);
      txt(c, '+', Offset(x + 8 + rnd.nextDouble() * (w / 2 - dw / 2 - 24), py), fs: 16, col: Colors.red);
      txt(c, '−', Offset(mid + dw / 2 + 8 + rnd.nextDouble() * (w / 2 - dw / 2 - 24), py), fs: 18, col: Colors.blue);
    }
    txt(c, 'P', Offset(x + 4, top + 2), fs: 14); txt(c, 'N', Offset(x + w - 14, top + 2), fs: 14);
    txt(c, 'depletion', Offset(mid, top + hh + 6), fs: 12, center: true);
    final a = Paint()..color = Colors.black87..strokeWidth = 2;
    final y = s.height - 16;
    if (mode == 1) { c.drawLine(Offset(x + 20, y), Offset(mid - 10, y), a); c.drawLine(Offset(x + w - 20, y), Offset(mid + 10, y), a); txt(c, 'carriers pushed toward junction', Offset(mid, y + 2), fs: 11, center: true); }
    if (mode == 2) { c.drawLine(Offset(mid - 10, y), Offset(x + 20, y), a); c.drawLine(Offset(mid + 10, y), Offset(x + w - 20, y), a); txt(c, 'carriers pulled away', Offset(mid, y + 2), fs: 11, center: true); }
    if (mode == 0) txt(c, 'P-N junction (no bias)', Offset(mid, y), fs: 12, center: true);
  }
  @override
  bool shouldRepaint(covariant StructPainter o) => o.mode != mode;
}

class CircuitPainter extends CustomPainter {
  final bool fwd; CircuitPainter(this.fwd);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = Colors.black87..strokeWidth = 2..style = PaintingStyle.stroke;
    final l = 40.0, r = s.width - 50, t = 40.0, b = s.height - 40, my = (t + b) / 2, mx = (l + r) / 2;
    // wires
    c.drawLine(Offset(l, t), Offset(mx - 30, t), p); c.drawLine(Offset(mx + 30, t), Offset(r, t), p);
    c.drawLine(Offset(l, t), Offset(l, my - 10), p); c.drawLine(Offset(l, my + 10), Offset(l, b), p);
    c.drawLine(Offset(l, b), Offset(r, b), p);
    c.drawLine(Offset(r, t), Offset(r, my - 20), p); c.drawLine(Offset(r, my + 20), Offset(r, b), p);
    // battery
    c.drawLine(Offset(l - 14, my - 10), Offset(l + 14, my - 10), p); c.drawLine(Offset(l - 8, my + 10), Offset(l + 8, my + 10), p);
    txt(c, '+', Offset(l + 16, my - 22), fs: 14); txt(c, 'V', Offset(l - 34, my - 8), fs: 13);
    // resistor
    final z = Path()..moveTo(mx - 30, t);
    for (int i = 0; i < 6; i++) { z.lineTo(mx - 25 + i * 10, t + (i.isEven ? -8 : 8)); }
    z.lineTo(mx + 30, t); c.drawPath(z, p); txt(c, '1 kΩ', Offset(mx - 16, t - 28), fs: 12);
    // diode (triangle direction = conventional current flow if forward)
    final d = Path();
    if (fwd) { d..moveTo(r - 16, my - 20)..lineTo(r + 16, my - 20)..lineTo(r, my + 14)..close(); c.drawLine(Offset(r - 16, my + 16), Offset(r + 16, my + 16), p); }
    else { d..moveTo(r - 16, my + 20)..lineTo(r + 16, my + 20)..lineTo(r, my - 14)..close(); c.drawLine(Offset(r - 16, my - 16), Offset(r + 16, my - 16), p); }
    c.drawPath(d, p);
    txt(c, fwd ? 'A (P)' : 'K (N)', Offset(r + 20, my - 24), fs: 11); txt(c, fwd ? 'K (N)' : 'A (P)', Offset(r + 20, my + 12), fs: 11);
    txt(c, fwd ? 'I flows →↓ (ON)' : 'I ≈ 0 (OFF)', Offset(mx, my), fs: 13, col: fwd ? Colors.green.shade700 : Colors.red, center: true);
  }
  @override
  bool shouldRepaint(covariant CircuitPainter o) => o.fwd != fwd;
}