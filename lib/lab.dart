import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'physics.dart';
import 'plots.dart';
import 'theme.dart';

// ---------------- Breadboard geometry ----------------
const rowY = [90.0, 108.0, 126.0, 144.0, 162.0, 202.0, 220.0, 238.0, 256.0, 274.0];
const terms = {'T:S+': Offset(110, 350), 'T:S-': Offset(170, 350), 'T:A+': Offset(430, 350), 'T:A-': Offset(490, 350), 'T:V+': Offset(710, 350), 'T:V-': Offset(770, 350)};
const boardW = 940.0, boardH = 590.0;
Offset hole(int c, int r) => Offset(70 + c * 28.0, rowY[r]);
Offset kpos(String k) {
  final s = k.split(':');
  if (s[0] == 'H') return hole(int.parse(s[1]), int.parse(s[2]));
  if (s[0] == 'R') return Offset(70 + int.parse(s[1]) * 28.0, s[2] == 'p' ? 30 : 48);
  return terms[k]!;
}
String node(String k) {
  final s = k.split(':');
  if (s[0] == 'H') return 'h${s[1]}${int.parse(s[2]) < 5 ? 't' : 'b'}'; // five tied holes per column strip
  if (s[0] == 'R') return 'r${s[2]}'; // whole power rail
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
class Sim {
  final String msg; final bool ok, warn, closed, fwd, hasD; final double? iMa, vv; final double loopA, vd;
  const Sim(this.msg, this.ok, {this.warn = false, this.closed = false, this.fwd = true, this.hasD = false, this.iMa, this.vv, this.loopA = 0, this.vd = 0});
}

Sim simulate(List<Part> parts, List<Wire> wires, double vs, double rOhm, DiodeModel dm, double temp) {
  final uf = <String, String>{};
  String f(String x) { uf.putIfAbsent(x, () => x); while (uf[x] != x) { uf[x] = uf[uf[x]!]!; x = uf[x]!; } return x; }
  for (final w in wires) { uf[f(node(w.a))] = f(node(w.b)); }
  if (f('T:S+') == f('T:S-')) return const Sim('Short circuit across the supply – remove a wire!', false);
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
  if (path == null) return const Sim('Open circuit – no complete path from supply + to supply −. Check your wires and parts.', false);
  final hasR = path.any((s) => s[0] == 'R');
  final ds = path.where((s) => s[0] == 'D').toList();
  final hasD = ds.isNotEmpty;
  final fwd = !hasD || ds.first[1] == true;
  if (!hasR && !hasD) return const Sim('Short circuit through the ammeter – add the resistor and diode to the loop.', false);
  final loop = solveLoop(vs, rOhm, dm, temp, fwd, hasR, hasD);
  if (!hasR && fwd && loop.i > 1) return const Sim('No series resistor in the loop – a forward diode would draw unlimited current and burn out!', false);
  final pot = <String, double>{f('T:S+'): vs};
  double cur = vs;
  for (final s in path) {
    if (s[0] == 'R') { cur -= loop.i * rOhm; } else if (s[0] == 'D') { cur -= loop.x; }
    pot[s[2] as String] = cur.abs() < 1e-9 ? 0 : cur;
  }
  final aStep = path.where((s) => s[0] == 'A').toList();
  final iMa = aStep.isEmpty ? null : (aStep.first[1] == true ? loop.i : -loop.i) * 1000;
  final vp = pot[f('T:V+')], vn = pot[f('T:V-')];
  final vv = (vp == null || vn == null) ? null : vp - vn;
  var msg = 'Circuit closed – ${hasD ? 'diode is ${fwd ? 'forward' : 'reverse'} biased' : 'no diode in the loop'}.';
  var warn = false;
  if (iMa == null) { msg += ' Put the ammeter in series.'; } else if (vv == null) { msg += ' Connect the voltmeter across the diode.'; }
  if (hasD && dm.led && fwd && loop.i > 0.030) { msg += ' ⚠ LED over-driven (${fmtCur(loop.i * 1000)}) – increase R.'; warn = true; }
  if (hasD && dm.vz != null && !fwd && loop.i > 1e-4) { msg += ' Zener breakdown – voltage is clamped near ${dm.vz} V.'; }
  return Sim(msg, true, warn: warn, closed: true, fwd: fwd, hasD: hasD, iMa: iMa, vv: vv, loopA: loop.i, vd: hasD ? (fwd ? loop.x : -loop.x) : 0);
}

// ---------------- Lab page ----------------
class LabPage extends StatefulWidget {
  final VoidCallback onResults;
  const LabPage({super.key, required this.onResults});
  @override
  State<LabPage> createState() => _LabS();
}

class _LabS extends State<LabPage> {
  final canvasKey = GlobalKey();
  final parts = <Part>[]; final wires = <Wire>[];
  String? pending; String? armed; bool erase = false;
  double vs = 0, rOhm = 1000, temp = 300, zoom = .75;
  int mi = 0; Timer? sweep; int sweepIdx = 0;
  static const sweepList = [0.0, 0.3, 0.5, 0.7, 0.9, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 7.0, 10.0, 15.0, 20.0, 30.0];
  DiodeModel get dm => models[mi];
  Sim simAt(double v) => simulate(parts, wires, v, rOhm, dm, temp);

  @override
  void dispose() { sweep?.cancel(); super.dispose(); }

  String? hit(Offset p) {
    String? best; double bd = 14;
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
  void msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 2)));

  void place(String type, Offset p) {
    int bc = -1, br = 0; double bd = 44;
    for (int c = 0; c <= 25; c++) { for (int r = 0; r < 10; r++) { final d = (hole(c, r) - p).distance; if (d < bd) { bd = d; bc = c; br = r; } } }
    if (bc < 0) return;
    if (parts.any((q) => q.type != type && q.row == br && (q.col - bc).abs() < 5)) { msg('Those holes are already occupied.'); return; }
    setState(() { final old = parts.where((q) => q.type == type).firstOrNull; parts.removeWhere((q) => q.type == type); parts.add(Part(type, bc, br, old?.flip ?? false)); armed = null; });
  }
  void tap(Offset p) {
    if (armed != null) { place(armed!, p); return; }
    final q = partAt(p);
    if (q != null) { setState(() { if (erase) { parts.remove(q); } else if (q.type == 'D') { q.flip = !q.flip; } }); return; }
    final k = hit(p);
    setState(() {
      if (erase) { if (k != null) wires.removeWhere((w) => w.a == k || w.b == k); pending = null; }
      else if (k == null || k == pending) { pending = null; }
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
    final rb = canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb != null) place(type, rb.globalToLocal(g));
  }
  void loadReference() => setState(() {
        parts..clear()..addAll([Part('R', 3, 0), Part('D', 14, 0)]);
        wires.clear(); pending = null; armed = null;
        for (final w in [['T:S+', 'H:3:1'], ['H:7:1', 'T:A+'], ['T:A-', 'H:14:1'], ['H:18:1', 'T:S-'], ['T:V+', 'H:14:2'], ['T:V-', 'H:18:2']]) {
          wires.add(Wire(w[0], w[1], wireColor(w[0], w[1], wires.length)));
        }
      });

  bool canRec(Sim s) => s.ok && s.iMa != null && s.vv != null;
  void addRecord(double v) {
    final s = simAt(v);
    if (!canRec(s)) return;
    final l = [...records.value]..removeWhere((r) => (r.vs - v).abs() < 1e-6 && r.model == dm.id && r.r == rOhm);
    l.add(Rec(v, s.vv!, s.iMa!, dm.id, temp, rOhm));
    l.sort((a, b) => a.model == b.model ? a.vs.compareTo(b.vs) : a.model.compareTo(b.model));
    records.value = l;
  }
  void toggleSweep() {
    if (sweep != null) { sweep!.cancel(); setState(() => sweep = null); return; }
    if (!canRec(simAt(0))) { msg('Complete the reference circuit (with ammeter + voltmeter) first.'); return; }
    sweepIdx = 0;
    sweep = Timer.periodic(const Duration(milliseconds: 220), (t) {
      if (sweepIdx >= sweepList.length) { t.cancel(); setState(() => sweep = null); return; }
      setState(() { vs = sweepList[sweepIdx++]; addRecord(vs); });
    });
    setState(() {});
  }
  String csv() => ['model,R_ohm,T_K,Vs_V,Vd_V,Id_mA', for (final r in records.value) '${r.model},${r.r.toStringAsFixed(0)},${r.temp.toStringAsFixed(0)},${r.vs},${r.vd.toStringAsFixed(4)},${r.id.toStringAsFixed(5)}'].join('\n');

  // ----- widgets -----
  Widget tile(String t) {
    final on = armed == t;
    final w = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: on ? const Color(0xFFDCE8FB) : Colors.white, border: Border.all(color: on ? C.accent : C.lo, width: on ? 2 : 1), borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 26, height: 10, decoration: BoxDecoration(color: t == 'R' ? const Color(0xFFE6C48F) : dm.body, borderRadius: BorderRadius.circular(5), border: Border.all(color: C.edge, width: .8))),
        const SizedBox(width: 8),
        Text(t == 'R' ? '${fmtOhm(rOhm)} resistor' : '${dm.part} ${dm.name}', style: ui(13, w: FontWeight.w600)),
      ]),
    );
    return Draggable<String>(
      data: t, dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(color: Colors.transparent, child: Transform.translate(offset: const Offset(-20, -20), child: w)),
      childWhenDragging: Opacity(opacity: .4, child: w),
      child: GestureDetector(onTap: () => setState(() => armed = on ? null : t), child: MouseRegion(cursor: SystemMouseCursors.click, child: w)),
    );
  }

  Widget board(Sim s) {
    final canvas = DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => drop(d.data, d.offset),
      builder: (c, a, b) => SizedBox(key: canvasKey, width: boardW, height: boardH, child: GestureDetector(
        onTapUp: (d) => tap(d.localPosition),
        onLongPressStart: (d) => remove(d.localPosition),
        child: CustomPaint(painter: BoardPainter(parts, wires, pending, vs, s, rOhm, dm)))),
    );
    return LayoutBuilder(builder: (c, bc) {
      final narrow = bc.maxWidth < 640;
      final toolbar = Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Btn('Wire', compact: true, selected: !erase, onTap: () => setState(() { erase = false; })),
        Btn('Erase', compact: true, selected: erase, onTap: () => setState(() { erase = true; pending = null; })),
        Btn('Reference circuit', compact: true, primary: true, onTap: loadReference),
        Btn('Clear wires', compact: true, onTap: () => setState(() { wires.clear(); pending = null; })),
        Btn('Clear all', compact: true, onTap: () => setState(() { wires.clear(); parts.clear(); pending = null; })),
        if (narrow) ...[
          Btn('−', compact: true, onTap: () => setState(() => zoom = max(.45, zoom - .15))),
          Btn('+', compact: true, onTap: () => setState(() => zoom = min(1.3, zoom + .15))),
        ],
      ]);
      final view = narrow
          ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: boardW * zoom, height: boardH * zoom, child: FittedBox(fit: BoxFit.fill, child: canvas)))
          : AspectRatio(aspectRatio: boardW / boardH, child: FittedBox(fit: BoxFit.contain, child: canvas));
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        toolbar, const SizedBox(height: 10),
        Container(decoration: BoxDecoration(border: Border.all(color: C.edge), color: const Color(0xFFB9B9BE)), padding: const EdgeInsets.all(6), child: view),
        if (narrow) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Swipe sideways to pan · − / + to zoom', style: ui(11, c: C.ink3))),
      ]);
    });
  }

  Widget livePlot(Sim s) {
    final rev = s.hasD && !s.fwd;
    final tt = temp;
    final xMax = rev ? 30.0 : dm.vMax;
    final curve = <Series>[];
    final pts = <Offset>[];
    for (int i = 0; i <= 240; i++) {
      final v = rev ? -xMax * (1 - i / 240) : xMax * i / 240;
      pts.add(Offset(v, dm.current(v, tt) * 1000));
    }
    curve.add(Series(pts, color: C.accent));
    final ll = rev ? [Offset(-vs, 0), Offset(0, -vs / rOhm * 1000)] : [Offset(0, vs / rOhm * 1000), Offset(vs, 0)];
    if (vs > 0) curve.add(Series(ll, color: C.amber, w: 1.8, dashed: true));
    final lp = solveLoop(vs, rOhm, dm, tt, !rev, true, true);
    final q = rev ? Offset(-lp.x, -lp.i * 1000) : Offset(lp.x, lp.i * 1000);
    final mine = records.value.where((r) => r.model == dm.id && (rev ? r.vd < 0 : r.vd >= 0)).map((r) => Offset(r.vd, r.id)).toList();
    if (mine.isNotEmpty) curve.add(Series(mine, color: C.bad, w: 0, dots: true));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(height: 300, child: CustomPaint(painter: Plot(curve, rev ? -xMax : 0, xMax, rev ? -30 : 0, rev ? 0 : 30, rev ? 'Vd (V) – reverse' : 'Vd (V)', 'Id (mA)', mark: vs > 0 ? q : null, markLabel: 'Q ${lp.x.toStringAsFixed(2)} V · ${fmtCur(lp.i * 1000)}'))),
      const SizedBox(height: 8),
      Text('Blue: ${dm.part} ${dm.name} at ${temp.round()} K · dashed: load line Vs − I·R · ● operating point · red dots: your readings.', style: ui(12, c: C.ink3)),
    ]);
  }

  @override
  Widget build(BuildContext c) {
    final s = simAt(vs);
    final l = records.value;
    final controls = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Caption('Diode under test'),
      Wrap(spacing: 8, runSpacing: 8, children: [for (int i = 0; i < models.length; i++) Btn(models[i].name, compact: true, selected: mi == i, onTap: () => setState(() => mi = i))]),
      Padding(padding: const EdgeInsets.only(top: 6), child: Text('${dm.part} – ${dm.blurb}', style: ui(12, c: C.ink3))),
      const Caption('Series resistor'),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final r in resistorValues) Btn(fmtOhm(r), compact: true, selected: rOhm == r, onTap: () => setState(() => rOhm = r))]),
      Caption('Temperature · ${temp.round()} K (${(temp - 273.15).round()} °C)'),
      Slider(value: temp, min: 250, max: 400, divisions: 150, label: '${temp.round()} K', onChanged: (v) => setState(() => temp = v)),
      Caption('Supply voltage'),
      Lcd('${vs.toStringAsFixed(2)} V', label: 'SUPPLY', size: 26),
      Slider(value: vs, min: 0, max: 30, divisions: 600, label: '${vs.toStringAsFixed(2)} V', onChanged: sweep != null ? null : (v) => setState(() => vs = v)),
      const Caption('Parts · drag onto the board, or tap then tap a hole'),
      Wrap(spacing: 10, runSpacing: 10, children: [tile('R'), tile('D')]),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Btn('Flip diode', compact: true, onTap: () => setState(() { for (final q in parts.where((q) => q.type == 'D')) { q.flip = !q.flip; } })),
      ]),
    ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Win('03 · Interactive circuit', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Para('Build: supply (+) → resistor → ammeter → diode anode, diode cathode → supply (−), voltmeter across the diode. Tap one terminal or hole, then another, to run a wire. Tap the diode to flip it. Or just press “Reference circuit”.'),
        board(s),
        const SizedBox(height: 12),
        Note(s.msg, ok: s.ok && !s.warn, warn: s.warn || !s.ok),
      ])),
      Cols(fa: 5, fb: 6, a: [
        Win('Bench controls', child: controls),
      ], b: [
        Win(s.hasD && !s.fwd ? 'Live V-I · reverse' : 'Live V-I · forward', child: livePlot(s)),
        Win('Data logger · ${l.length} readings', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            Btn('Record', primary: true, icon: Icons.fiber_manual_record, onTap: canRec(s) ? () => setState(() => addRecord(vs)) : null),
            Btn(sweep != null ? 'Stop sweep' : 'Auto-sweep', icon: sweep != null ? Icons.stop : Icons.play_arrow, onTap: toggleSweep),
            Btn('Copy CSV', onTap: l.isEmpty ? null : () { Clipboard.setData(ClipboardData(text: csv())); msg('Copied ${l.length} rows as CSV'); }),
            Btn('Clear', onTap: l.isEmpty ? null : () => setState(() => records.value = [])),
            Btn('Results →', primary: true, onTap: l.length >= 3 ? widget.onResults : null),
          ]),
          const SizedBox(height: 10),
          if (l.length < 5) Text('Record at least 5 readings to unlock the full analysis (${l.length}/5). Auto-sweep does it for you.', style: ui(12, c: C.ink3)),
          const SizedBox(height: 6),
          DataGrid(const ['Vs (V)', 'Vd (V)', 'Id'], [for (final r in l.reversed.take(60)) [r.vs.toStringAsFixed(2), r.vd.toStringAsFixed(3), fmtCur(r.id)]], maxH: 260),
        ])),
      ]),
    ]);
  }
}

class DataGrid extends StatelessWidget {
  final List<String> head; final List<List<String>> rows; final double? maxH;
  const DataGrid(this.head, this.rows, {super.key, this.maxH});
  @override
  Widget build(BuildContext c) {
    final cell = ui(12.5, c: C.ink);
    final table = Table(
      defaultColumnWidth: const IntrinsicColumnWidth(flex: 1),
      border: const TableBorder(horizontalInside: BorderSide(color: Color(0xFFE2E2E2))),
      children: [
        TableRow(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF4F4F4), Color(0xFFD2D2D2)])),
            children: [for (final h in head) Padding(padding: const EdgeInsets.all(7), child: Text(h, style: ui(12, w: FontWeight.w700, c: C.ink2)))]),
        for (int i = 0; i < rows.length; i++)
          TableRow(decoration: BoxDecoration(color: i.isEven ? Colors.white : C.stripe), children: [for (final v in rows[i]) Padding(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5), child: Text(v, style: mono(12.5, w: FontWeight.w500)))]),
      ],
    );
    final body = rows.isEmpty ? Padding(padding: const EdgeInsets.all(14), child: Text('No readings yet.', style: cell.copyWith(color: C.ink3))) : table;
    return Inset(pad: EdgeInsets.zero, child: LayoutBuilder(builder: (c, bc) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH ?? double.infinity),
      child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: ConstrainedBox(constraints: BoxConstraints(minWidth: bc.maxWidth), child: maxH == null ? body : SingleChildScrollView(child: body))),
    )));
  }
}

// ---------------- Painter ----------------
class BoardPainter extends CustomPainter {
  final List<Part> parts; final List<Wire> wires; final String? pending; final double vs, rOhm; final Sim sim; final DiodeModel dm;
  BoardPainter(this.parts, this.wires, this.pending, this.vs, this.sim, this.rOhm, this.dm);

  static const bandCols = [Color(0xFF111111), Color(0xFF6D4C41), Color(0xFFE53935), Color(0xFFFB8C00), Color(0xFFFDD835), Color(0xFF43A047), Color(0xFF1E88E5), Color(0xFF8E24AA), Color(0xFF9E9E9E), Colors.white];

  void inst(Canvas c, Rect r, String title, String val) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(8));
    c.drawRRect(rr.shift(const Offset(0, 3)), Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    c.drawRRect(rr, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFEDEDED), Color(0xFFC2C2C2)]).createShader(r));
    c.drawRRect(rr, Paint()..style = PaintingStyle.stroke..color = C.edge..strokeWidth = 1.5);
    final lcd = Rect.fromLTWH(r.left + 22, r.top + 70, r.width - 44, 70);
    c.drawRect(lcd, Paint()..color = C.lcd);
    c.drawRect(lcd, Paint()..style = PaintingStyle.stroke..color = C.lo..strokeWidth = 2);
    c.drawLine(lcd.bottomLeft, lcd.bottomRight, Paint()..color = Colors.white..strokeWidth = 2);
    txt(c, val, Offset(lcd.right - 12, lcd.center.dy), fs: val.length > 9 ? 22 : 30, col: C.lcdInk, right: true, w: FontWeight.w600);
    txt(c, title, Offset(r.center.dx, r.bottom - 40), fs: 13, col: C.ink2, center: true, mono_: false, w: FontWeight.w700);
  }

  void part(Canvas c, Part q) {
    final a = hole(q.col, q.row), b = hole(q.col + 4, q.row), m = (a + b) / 2;
    c.drawLine(a, b, Paint()..color = const Color(0xFF9AA7AD)..strokeWidth = 3);
    if (q.type == 'R') {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: m, width: 58, height: 18), const Radius.circular(9)), Paint()..color = const Color(0xFFE6C48F));
      final s = rOhm.round().toString();
      final cols = [bandCols[int.parse(s[0])], bandCols[int.parse(s[1])], bandCols[s.length - 2], const Color(0xFFC9A227)];
      for (int i = 0; i < 4; i++) { c.drawRect(Rect.fromCenter(center: m + Offset(-17.0 + i * 11.5, 0), width: 4, height: 18), Paint()..color = cols[i]); }
    } else if (dm.led) {
      final on = sim.closed && sim.loopA > 0 && sim.fwd;
      final br = on ? (sim.loopA * 1000 / 15).clamp(0.08, 1.0) : 0.0;
      if (on) c.drawCircle(m, 12 + 24 * br, Paint()..color = const Color(0xFFFF3B30).withValues(alpha: .75 * br)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
      c.drawCircle(m, 13, Paint()..color = Color.lerp(const Color(0xFF7B1F1F), const Color(0xFFFF8A80), br)!);
      c.drawCircle(m, 13, Paint()..style = PaintingStyle.stroke..color = Colors.black54..strokeWidth = 1.5);
      c.drawCircle(m + const Offset(-4, -4), 3.5, Paint()..color = Colors.white.withValues(alpha: .55));
      c.drawLine(m + Offset(q.flip ? -13 : 13, -9), m + Offset(q.flip ? -13 : 13, 9), Paint()..color = Colors.black54..strokeWidth = 2);
      txt(c, q.flip ? 'K   A' : 'A   K', m + const Offset(0, 24), fs: 10, col: C.ink3, center: true);
    } else {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: m, width: 60, height: 16), const Radius.circular(3)), Paint()..color = dm.body);
      final kx = q.flip ? -24.0 : 24.0;
      c.drawRect(Rect.fromCenter(center: m + Offset(kx, 0), width: 7, height: 16), Paint()..color = dm.band);
      txt(c, dm.part, m + Offset(q.flip ? 4 : -4, 0), fs: 8, col: dm.body.computeLuminance() > .5 ? C.ink : Colors.white, center: true);
      txt(c, q.flip ? 'K   A' : 'A   K', m + const Offset(0, 20), fs: 10, col: C.ink3, center: true);
    }
    for (final e in [a, b]) { c.drawCircle(e, 3.5, Paint()..color = const Color(0xFF90A4AE)); }
  }

  @override
  void paint(Canvas c, Size s) {
    const board = Rect.fromLTWH(10, 10, 920, 290);
    c.drawRRect(RRect.fromRectAndRadius(board.shift(const Offset(0, 4)), const Radius.circular(10)), Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    c.drawRRect(RRect.fromRectAndRadius(board, const Radius.circular(10)), Paint()..color = const Color(0xFFF4F0E6));
    c.drawRRect(RRect.fromRectAndRadius(board, const Radius.circular(10)), Paint()..style = PaintingStyle.stroke..color = const Color(0xFFBDB6A3)..strokeWidth = 2);
    c.drawRect(const Rect.fromLTWH(40, 177, 860, 10), Paint()..color = const Color(0xFFD9D3C0));
    c.drawLine(const Offset(50, 21), const Offset(890, 21), Paint()..color = Colors.red.shade300..strokeWidth = 2);
    c.drawLine(const Offset(50, 58), const Offset(890, 58), Paint()..color = Colors.blue.shade300..strokeWidth = 2);
    final hp = Paint()..color = const Color(0xFF455A64);
    for (int col = 0; col < 30; col++) {
      for (int r = 0; r < 10; r++) { c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: hole(col, r), width: 8, height: 8), const Radius.circular(2)), hp); }
      for (final y in [30.0, 48.0]) { c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(70 + col * 28.0, y), width: 8, height: 8), const Radius.circular(2)), hp); }
      if (col % 5 == 0) txt(c, '${col + 1}', Offset(70 + col * 28.0, 74), fs: 10, col: C.ink3, center: true);
    }
    for (int r = 0; r < 10; r++) { txt(c, 'abcdefghij'[r], Offset(46, rowY[r]), fs: 11, col: C.ink3, center: true); }
    txt(c, '+', const Offset(32, 30), fs: 15, col: Colors.red, center: true);
    txt(c, '−', const Offset(32, 48), fs: 15, col: Colors.blue, center: true);

    final iTxt = sim.ok && sim.iMa != null ? fmtCur(sim.iMa!) : '— —';
    final vTxt = sim.ok && sim.vv != null ? '${sim.vv!.toStringAsFixed(3)} V' : '— —';
    inst(c, const Rect.fromLTWH(30, 330, 290, 240), '0–30 V DC POWER SUPPLY', '${vs.toStringAsFixed(2)} V');
    inst(c, const Rect.fromLTWH(350, 330, 250, 240), 'AMMETER', iTxt);
    inst(c, const Rect.fromLTWH(630, 330, 250, 240), 'DIGITAL MULTIMETER', vTxt);
    for (final e in terms.entries) {
      final plus = e.key.endsWith('+');
      c.drawCircle(e.value, 11, Paint()..color = plus ? Colors.red.shade700 : Colors.black);
      c.drawCircle(e.value, 11, Paint()..style = PaintingStyle.stroke..color = Colors.white..strokeWidth = 2);
      txt(c, plus ? '+' : '−', e.value + const Offset(0, 25), fs: 15, col: plus ? Colors.red.shade700 : C.ink, center: true, w: FontWeight.w700);
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
