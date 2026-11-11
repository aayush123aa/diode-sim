import 'package:flutter_test/flutter_test.dart';
import 'package:ec_lab/physics.dart';
import 'package:ec_lab/lab.dart';

void main() {
  test('silicon diode knee near 0.6-0.7 V at 1 mA', () {
    final v = models[0].vfAt(1e-3, 300);
    expect(v, inInclusiveRange(0.55, 0.75));
  });
  test('LED knee near 1.8-2 V at 10 mA', () {
    expect(models[3].vfAt(10e-3, 300), inInclusiveRange(1.6, 2.1));
  });
  test('loop solver satisfies KVL', () {
    final l = solveLoop(5, 1000, models[0], 300, true, true, true);
    expect(l.x + 1000 * l.i, closeTo(5, 1e-6));
  });
  test('reverse diode passes only leakage; zener clamps', () {
    final r = solveLoop(10, 1000, models[0], 300, false, true, true);
    expect(r.i.abs(), lessThan(1e-6));
    final z = solveLoop(10, 1000, models[4], 300, false, true, true);
    expect(z.x, inInclusiveRange(5.0, 5.4));
  });
  test('reference circuit simulates', () {
    final parts = [Part('R', 3, 0), Part('D', 14, 0)];
    final wires = [for (final w in [['T:S+', 'H:3:1'], ['H:7:1', 'T:A+'], ['T:A-', 'H:14:1'], ['H:18:1', 'T:S-'], ['T:V+', 'H:14:2'], ['T:V-', 'H:18:2']]) Wire(w[0], w[1], wireColor(w[0], w[1], 0))];
    final s = simulate(parts, wires, 5, 1000, models[0], 300);
    expect(s.ok, true);
    expect(s.iMa, closeTo(4.3, .3));
    expect(s.vv, closeTo(0.7, .08));
    parts[1].flip = true;
    final r = simulate(parts, wires, 5, 1000, models[0], 300);
    expect(r.vv, closeTo(5, .01));
  });
}
