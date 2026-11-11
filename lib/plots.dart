import 'dart:math';
import 'package:flutter/material.dart';
import 'theme.dart';

void txt(Canvas c, String s, Offset o, {double fs = 11, Color col = C.ink, bool center = false, bool right = false, bool mono_ = true, FontWeight w = FontWeight.w500}) {
  final t = TextPainter(text: TextSpan(text: s, style: mono_ ? mono(fs, c: col, w: w) : ui(fs, c: col, w: w)), textDirection: TextDirection.ltr)..layout();
  c.save();
  t.paint(c, center ? o - Offset(t.width / 2, t.height / 2) : right ? o - Offset(t.width, t.height / 2) : o);
  c.restore();
}

String fmtTick(double v) {
  final a = v.abs();
  if (a < 1e-12) return '0';
  if (a >= 1000) return v.toStringAsFixed(0);
  if (a >= 10) return v.toStringAsFixed(a == a.roundToDouble() ? 0 : 1);
  if (a >= 1) return v.toStringAsFixed(a * 10 == (a * 10).roundToDouble() ? 1 : 2).replaceAll(RegExp(r'\.0$'), '');
  if (a >= 0.001) return v.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  return v.toStringAsExponential(0);
}

List<double> niceTicks(double a, double b, int n) {
  final raw = (b - a) / n;
  final mag = pow(10, (log(raw) / ln10).floor()).toDouble();
  final f = raw / mag;
  final step = (f < 1.5 ? 1 : f < 3.5 ? 2 : f < 7.5 ? 5 : 10) * mag;
  final out = <double>[];
  for (double v = (a / step).ceil() * step; v <= b + step * 1e-6; v += step) { out.add(double.parse(v.toStringAsPrecision(10))); }
  return out;
}

class Series {
  final List<Offset> pts; final Color color; final double w; final bool dots, dashed;
  const Series(this.pts, {this.color = C.accent, this.w = 2.4, this.dots = false, this.dashed = false});
}

class Plot extends CustomPainter {
  final List<Series> series; final double x0, x1, y0, y1; final String xl, yl; final bool logY; final Offset? mark; final String? markLabel;
  const Plot(this.series, this.x0, this.x1, this.y0, this.y1, this.xl, this.yl, {this.logY = false, this.mark, this.markLabel});

  @override
  void paint(Canvas c, Size s) {
    final l = logY ? 46.0 : 44.0, b = 34.0, t = 14.0, r = 14.0;
    final w = s.width - l - r, hh = s.height - b - t;
    double fy(double y) => logY ? log(max(y, 1e-30)) / ln10 : y;
    final ya = fy(y0), yb = fy(y1);
    Offset m(Offset p) => Offset(l + (p.dx - x0) / (x1 - x0) * w, t + hh - (fy(p.dy) - ya) / (yb - ya) * hh);
    c.drawRect(Rect.fromLTWH(l, t, w, hh), Paint()..color = Colors.white);
    final grid = Paint()..color = const Color(0xFFE2E2E2)..strokeWidth = 1;
    for (final v in niceTicks(x0, x1, w > 360 ? 8 : 5)) {
      final x = l + (v - x0) / (x1 - x0) * w;
      c.drawLine(Offset(x, t), Offset(x, t + hh), grid);
      txt(c, fmtTick(v), Offset(x, t + hh + 12), fs: 10, col: C.ink3, center: true);
    }
    if (logY) {
      for (int e = ya.ceil(); e <= yb.floor(); e++) {
        final y = t + hh - (e - ya) / (yb - ya) * hh;
        c.drawLine(Offset(l, y), Offset(l + w, y), grid);
        txt(c, '1e$e', Offset(l - 4, y), fs: 10, col: C.ink3, right: true);
      }
    } else {
      for (final v in niceTicks(y0, y1, hh > 200 ? 6 : 4)) {
        final y = t + hh - (v - y0) / (y1 - y0) * hh;
        c.drawLine(Offset(l, y), Offset(l + w, y), grid);
        txt(c, fmtTick(v), Offset(l - 4, y), fs: 10, col: C.ink3, right: true);
      }
    }
    final ax = Paint()..color = C.ink..strokeWidth = 1.2;
    if (!logY && y0 < 0 && y1 > 0) { final y = m(const Offset(0, 0)).dy; c.drawLine(Offset(l, y), Offset(l + w, y), ax); }
    if (x0 < 0 && x1 > 0) { final x = m(Offset(0, y0)).dx; c.drawLine(Offset(x, t), Offset(x, t + hh), ax); }
    c.drawRect(Rect.fromLTWH(l, t, w, hh), Paint()..style = PaintingStyle.stroke..color = C.edge);
    txt(c, xl, Offset(l + w / 2, s.height - 6), fs: 11, col: C.ink2, center: true);
    txt(c, yl, Offset(l + 4, t + 9), fs: 11, col: C.ink2);

    c.save();
    c.clipRect(Rect.fromLTWH(l, t, w, hh));
    for (final se in series) {
      final pts = logY ? se.pts.where((p) => p.dy > 0).toList() : se.pts;
      if (pts.isEmpty) continue;
      final path = Path();
      for (int i = 0; i < pts.length; i++) { final q = m(pts[i]); i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy); }
      final paint = Paint()..color = se.color..strokeWidth = se.w..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round;
      if (se.dashed) {
        for (final mt in path.computeMetrics()) {
          for (double d = 0; d < mt.length; d += 10) { c.drawPath(mt.extractPath(d, min(d + 5, mt.length)), paint); }
        }
      } else if (se.w > 0 && pts.length > 1) { c.drawPath(path, paint); }
      if (se.dots) {
        for (final p in pts) {
          final q = m(p);
          c.drawCircle(q, 4.5, Paint()..color = Colors.white);
          c.drawCircle(q, 3.2, Paint()..color = se.color);
        }
      }
    }
    if (mark != null && (!logY || mark!.dy > 0)) {
      final q = m(mark!);
      c.drawCircle(q, 9, Paint()..color = C.amber.withValues(alpha: .25));
      c.drawCircle(q, 5, Paint()..color = C.amber);
      c.drawCircle(q, 5, Paint()..style = PaintingStyle.stroke..color = Colors.white..strokeWidth = 1.5);
    }
    c.restore();
    if (mark != null && markLabel != null) {
      final q = m(mark!);
      final lx = q.dx > l + w * .6 ? q.dx - 10 : q.dx + 12;
      if (q.dx >= l && q.dx <= l + w && q.dy >= t && q.dy <= t + hh) txt(c, markLabel!, Offset(lx, (q.dy - 16).clamp(t + 4, t + hh - 10)), fs: 10, col: C.amber, right: q.dx > l + w * .6, w: FontWeight.w700);
    }
  }
  @override
  bool shouldRepaint(covariant Plot o) => true;
}

/// P-N junction with animated carriers. bias in volts (+ forward), phase 0..1 loops.
class JunctionPainter extends CustomPainter {
  final double bias, phase, flow; // flow 0..1 = normalised forward current
  JunctionPainter(this.bias, this.phase, this.flow);
  @override
  void paint(Canvas c, Size s) {
    final x = 8.0, top = 8.0, w = s.width - 16, hh = s.height - 40, mid = x + w / 2;
    final base = w * .16;
    final dw = bias >= 0 ? base * (1 - (bias / 0.85).clamp(0, 1) * .85) : base * (1 + sqrt(-bias) * .55);
    final pw = w / 2 - dw / 2;
    c.drawRect(Rect.fromLTWH(x, top, pw, hh), Paint()..color = const Color(0xFFF3CFCF));
    c.drawRect(Rect.fromLTWH(mid + dw / 2, top, pw, hh), Paint()..color = const Color(0xFFCFDDF3));
    c.drawRect(Rect.fromLTWH(mid - dw / 2, top, dw, hh), Paint()..color = const Color(0xFFD8D8D8));
    c.drawRect(Rect.fromLTWH(x, top, w, hh), Paint()..style = PaintingStyle.stroke..color = C.edge);
    // fixed ions in the depletion region
    final ionP = Paint()..color = C.ink3.withValues(alpha: .5);
    for (double yy = top + 14; yy < top + hh - 6; yy += 22) {
      txt(c, '−', Offset(mid - dw / 4, yy), fs: 12, col: ionP.color, center: true);
      txt(c, '+', Offset(mid + dw / 4, yy), fs: 12, col: ionP.color, center: true);
    }
    final rnd = Random(7);
    final speed = bias > 0.3 ? (.25 + .75 * flow) : 0.0;
    for (int i = 0; i < 16; i++) {
      final yy = top + 14 + rnd.nextDouble() * (hh - 28), u = rnd.nextDouble();
      final ph = (u + phase * speed * (1 + (i % 3) * .15)) % 1.0;
      final hx = x + 10 + ph * (pw - 20); // holes move toward the junction (right)
      final ex = mid + dw / 2 + 10 + (1 - ph) * (pw - 20); // electrons move left
      txt(c, '+', Offset(hx, yy), fs: 16, col: const Color(0xFFC62828), center: true, w: FontWeight.w700);
      txt(c, '−', Offset(ex, yy + 3), fs: 18, col: const Color(0xFF1565C0), center: true, w: FontWeight.w700);
    }
    txt(c, 'P', Offset(x + 14, top + 12), fs: 14, col: C.ink2, w: FontWeight.w700);
    txt(c, 'N', Offset(x + w - 14, top + 12), fs: 14, col: C.ink2, w: FontWeight.w700);
    final y = s.height - 20;
    txt(c, 'depletion ${(dw / w * 100).toStringAsFixed(0)}%', Offset(mid, y - 6), fs: 10, col: C.ink2, center: true);
    final a = Paint()..color = C.ink..strokeWidth = 2;
    final label = bias > 0.3 ? 'carriers driven into the junction' : bias < 0 ? 'carriers pulled away – barrier grows' : 'barrier holds carriers back';
    if (bias < 0) {
      c.drawLine(Offset(mid - 12, y + 10), Offset(x + 30, y + 10), a); c.drawLine(Offset(mid + 12, y + 10), Offset(x + w - 30, y + 10), a);
    } else if (bias > 0.3) {
      c.drawLine(Offset(x + 30, y + 10), Offset(mid - 12, y + 10), a); c.drawLine(Offset(x + w - 30, y + 10), Offset(mid + 12, y + 10), a);
    }
    txt(c, label, Offset(mid, y + 10), fs: 10, col: C.ink3, center: true, mono_: false);
  }
  @override
  bool shouldRepaint(covariant JunctionPainter o) => true;
}

/// Schematic with moving conventional-current dots.
class SchematicPainter extends CustomPainter {
  final bool fwd; final double phase, flow;
  SchematicPainter(this.fwd, this.phase, this.flow);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = C.ink..strokeWidth = 2..style = PaintingStyle.stroke;
    final l = 44.0, r = s.width - 56, t = 44.0, b = s.height - 34, my = (t + b) / 2, mx = (l + r) / 2;
    c.drawLine(Offset(l, t), Offset(mx - 30, t), p); c.drawLine(Offset(mx + 30, t), Offset(r, t), p);
    c.drawLine(Offset(l, t), Offset(l, my - 10), p); c.drawLine(Offset(l, my + 10), Offset(l, b), p);
    c.drawLine(Offset(l, b), Offset(r, b), p);
    c.drawLine(Offset(r, t), Offset(r, my - 20), p); c.drawLine(Offset(r, my + 20), Offset(r, b), p);
    c.drawLine(Offset(l - 14, my - 10), Offset(l + 14, my - 10), p);
    c.drawLine(Offset(l - 8, my + 10), Offset(l + 8, my + 10), Paint()..color = C.ink..strokeWidth = 4);
    txt(c, '+', Offset(l + 18, my - 18), fs: 14, w: FontWeight.w700); txt(c, 'Vs', Offset(l - 30, my), fs: 12, center: true);
    final z = Path()..moveTo(mx - 30, t);
    for (int i = 0; i < 6; i++) { z.lineTo(mx - 25 + i * 10, t + (i.isEven ? -8 : 8)); }
    z.lineTo(mx + 30, t); c.drawPath(z, p); txt(c, 'R = 1 kΩ', Offset(mx, t - 24), fs: 11, center: true);
    final d = Path();
    if (fwd) { d..moveTo(r - 16, my - 20)..lineTo(r + 16, my - 20)..lineTo(r, my + 14)..close(); c.drawLine(Offset(r - 16, my + 16), Offset(r + 16, my + 16), p); }
    else { d..moveTo(r - 16, my + 20)..lineTo(r + 16, my + 20)..lineTo(r, my - 14)..close(); c.drawLine(Offset(r - 16, my - 16), Offset(r + 16, my - 16), p); }
    c.drawPath(d, Paint()..color = const Color(0xFFEEEEEE));
    c.drawPath(d, p);
    txt(c, fwd ? 'A' : 'K', Offset(r + 22, my - 20), fs: 11, col: C.ink3); txt(c, fwd ? 'K' : 'A', Offset(r + 22, my + 14), fs: 11, col: C.ink3);
    if (fwd) {
      final per = ((r - l) + (b - t)) * 2;
      Offset at(double d) {
        d = d % per;
        final top = r - l, side = b - t;
        if (d < top) return Offset(l + d, t);
        d -= top; if (d < side) return Offset(r, t + d);
        d -= side; if (d < top) return Offset(r - d, b);
        d -= top; return Offset(l, b - d);
      }
      final n = 18;
      for (int i = 0; i < n; i++) { c.drawCircle(at((i / n + phase * (.3 + .7 * flow)) * per), 3, Paint()..color = C.accent); }
    }
    txt(c, fwd ? 'ON · current flows' : 'OFF · I ≈ 0', Offset(mx, my), fs: 12, col: fwd ? C.ok : C.bad, center: true, w: FontWeight.w700);
  }
  @override
  bool shouldRepaint(covariant SchematicPainter o) => true;
}
