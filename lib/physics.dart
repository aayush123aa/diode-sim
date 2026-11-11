import 'dart:math';
import 'package:flutter/material.dart';

const kB = 1.380649e-23, qe = 1.602176634e-19;

/// A diode family described by the Shockley equation (+ optional breakdown).
class DiodeModel {
  final String id, name, part, blurb;
  final double isat; // saturation current @300 K
  final double n; // ideality factor
  final double eg; // bandgap-like activation energy (eV)
  final double? vz; // reverse breakdown voltage (Zener)
  final double vMax; // plot range (V) for forward curve
  final Color body, band;
  final bool led;
  const DiodeModel(this.id, this.name, this.part, this.blurb, this.isat, this.n, this.eg, this.vMax, this.body, this.band,
      {this.vz, this.led = false});

  double isatT(double t) => isat * pow(t / 300, 3 / n) * exp(eg * qe / (n * kB) * (1 / 300 - 1 / t));

  /// Diode current in amps for voltage v (anode - cathode) at temperature t (K).
  double current(double v, double t) {
    final vt = kB * t / qe;
    var i = isatT(t) * (exp(min(v / (n * vt), 700)) - 1);
    if (vz != null && v < 0) i -= 1e-3 * exp(min((-v - vz!) / 0.05, 700));
    return i;
  }

  /// Forward voltage at a given current (A).
  double vfAt(double amps, double t) {
    double lo = 0, hi = 4;
    for (int k = 0; k < 60; k++) {
      final m = (lo + hi) / 2;
      if (current(m, t) < amps) { lo = m; } else { hi = m; }
    }
    return (lo + hi) / 2;
  }
}

const models = <DiodeModel>[
  DiodeModel('si', 'Silicon', '1N4007', 'General purpose rectifier. Knee ≈ 0.7 V.', 2.5e-9, 1.9, 1.12, 1.0,
      Color(0xFF212121), Color(0xFFCFD8DC)),
  DiodeModel('sch', 'Schottky', '1N5819', 'Metal–semiconductor junction. Knee ≈ 0.3 V, very fast.', 3e-7, 1.1, 0.6, 0.6,
      Color(0xFF37474F), Color(0xFFECEFF1)),
  DiodeModel('ge', 'Germanium', '1N34A', 'Early point-contact diode. Knee ≈ 0.25 V, leaky.', 2e-6, 1.3, 0.67, 0.6,
      Color(0xFFBCAAA4), Color(0xFF3E2723)),
  DiodeModel('led', 'Red LED', '5 mm', 'Wide-bandgap junction that emits light. Knee ≈ 1.8 V.', 1e-18, 2.0, 1.9, 2.6,
      Color(0xFFE53935), Color(0xFFFFCDD2), led: true),
  DiodeModel('zen', 'Zener 5.1 V', '1N4733', 'Forward like Si, but conducts in reverse at 5.1 V.', 2.5e-9, 1.9, 1.12, 1.0,
      Color(0xFFFFB74D), Color(0xFF212121), vz: 5.1),
];

const resistorValues = <double>[100, 220, 470, 1000, 2200, 4700, 10000];
String fmtOhm(double r) => r >= 1000 ? '${(r / 1000).toString().replaceAll(RegExp(r'\.0$'), '')} kΩ' : '${r.toStringAsFixed(0)} Ω';

/// Solution of Vs = x + R·g(x) where x is the diode drop in the direction of travel.
class Loop { final double x, i; Loop(this.x, this.i); }
Loop solveLoop(double vs, double r, DiodeModel m, double t, bool fw, bool hasR, bool hasD) {
  double g(double x) => fw ? m.current(x, t) : -m.current(-x, t);
  if (!hasD) return Loop(0, hasR ? vs / r : 0);
  if (!hasR) return Loop(vs, g(vs));
  double lo = 0, hi = vs;
  for (int k = 0; k < 80; k++) {
    final mid = (lo + hi) / 2;
    if (mid + r * g(mid) - vs < 0) { lo = mid; } else { hi = mid; }
  }
  final x = (lo + hi) / 2;
  return Loop(x, g(x));
}

class Rec {
  final double vs, vd, id, temp; // id in mA
  final String model;
  final double r;
  Rec(this.vs, this.vd, this.id, this.model, this.temp, this.r);
}

final records = ValueNotifier<List<Rec>>([]);

/// Autoranging current text from milliamps.
String fmtCur(double ma) {
  final a = ma.abs();
  if (a < 1e-6) return '0.000 mA';
  if (a < 0.1) return '${(ma * 1000).toStringAsFixed(a < 0.01 ? 2 : 1)} µA';
  return '${ma.toStringAsFixed(a >= 100 ? 1 : 3)} mA';
}

class Fit { final double n, isA; Fit(this.n, this.isA); }
/// Least-squares fit of ln(I) = ln(Is) + Vd/(n·Vt) over forward points.
Fit? fitShockley(List<Rec> l) {
  final p = l.where((r) => r.id > 0.02 && r.vd > 0.05).toList();
  if (p.length < 3) return null;
  final t = p.map((e) => e.temp).reduce((a, b) => a + b) / p.length;
  final vt = kB * t / qe;
  final xs = p.map((e) => e.vd).toList(), ys = p.map((e) => log(e.id / 1000)).toList();
  final mx = xs.reduce((a, b) => a + b) / xs.length, my = ys.reduce((a, b) => a + b) / ys.length;
  double sxy = 0, sxx = 0;
  for (int k = 0; k < xs.length; k++) { sxy += (xs[k] - mx) * (ys[k] - my); sxx += (xs[k] - mx) * (xs[k] - mx); }
  if (sxx < 1e-9 || sxy <= 0) return null;
  final slope = sxy / sxx;
  return Fit(1 / (slope * vt), exp(my - slope * mx));
}
