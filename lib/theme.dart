import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette lifted from the "classic desktop" look: grey desk, bevelled chrome, LCD green.
class C {
  static const desk = Color(0xFF8E8E93), chrome = Color(0xFFDCDCDC), chrome2 = Color(0xFFC8C8C8), paper = Color(0xFFFFFFFF),
      stripe = Color(0xFFF2F2F2), edge = Color(0xFF555555), hi = Color(0xFFFFFFFF), lo = Color(0xFF8A8A8A),
      ink = Color(0xFF111111), ink2 = Color(0xFF444444), ink3 = Color(0xFF777777), accent = Color(0xFF2F6FD0),
      accentHi = Color(0xFF6AA2EE), accentLo = Color(0xFF1A4A99), lcd = Color(0xFFC6D3A6), lcdInk = Color(0xFF1B2A0C),
      amber = Color(0xFFC27A00), amberWash = Color(0xFFFFF0CC), ok = Color(0xFF2E7D32), okWash = Color(0xFFE3F1D9), bad = Color(0xFFB3261E);
}

TextStyle ui(double s, {FontWeight w = FontWeight.w400, Color c = C.ink, double h = 1.4, double ls = 0}) =>
    GoogleFonts.notoSans(fontSize: s, fontWeight: w, color: c, height: h, letterSpacing: ls);
TextStyle mono(double s, {FontWeight w = FontWeight.w500, Color c = C.ink, double h = 1.3}) =>
    GoogleFonts.sourceCodePro(fontSize: s, fontWeight: w, color: c, height: h);

bool isNarrow(BuildContext c) => MediaQuery.sizeOf(c).width < 700;

const _bevelIn = Border(top: BorderSide(color: C.lo), left: BorderSide(color: C.lo), bottom: BorderSide(color: C.hi), right: BorderSide(color: C.hi));

/// A window with a title bar, like each section on the reference site.
class Win extends StatelessWidget {
  final String title; final Widget child; final EdgeInsets pad; final Widget? trailing; final Color? bg;
  const Win(this.title, {super.key, required this.child, this.pad = const EdgeInsets.all(14), this.trailing, this.bg});
  @override
  Widget build(BuildContext c) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: bg ?? C.chrome, borderRadius: BorderRadius.circular(5), border: Border.all(color: C.edge),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 5))]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Container(
              height: 26, padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF6F6F6), Color(0xFFCDCDCD)]),
                  border: Border(bottom: BorderSide(color: C.edge))),
              child: Row(children: [
                Container(width: 11, height: 11, decoration: BoxDecoration(border: Border.all(color: C.edge), gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Color(0xFFBDBDBD)]))),
                Expanded(child: Text(title, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: ui(12, w: FontWeight.w700, c: C.ink2, ls: .3))),
                SizedBox(width: 11, child: trailing),
              ]),
            ),
            Padding(padding: pad, child: child),
          ]),
        ),
      );
}

/// Sunken white panel.
class Inset extends StatelessWidget {
  final Widget child; final EdgeInsets pad; final Color color;
  const Inset({super.key, required this.child, this.pad = const EdgeInsets.all(10), this.color = C.paper});
  @override
  Widget build(BuildContext c) => Container(padding: pad, decoration: BoxDecoration(color: color, border: _bevelIn), child: child);
}

class Btn extends StatefulWidget {
  final String label; final VoidCallback? onTap; final bool primary, selected; final IconData? icon; final bool compact;
  const Btn(this.label, {super.key, this.onTap, this.primary = false, this.selected = false, this.icon, this.compact = false});
  @override
  State<Btn> createState() => _BtnS();
}
class _BtnS extends State<Btn> {
  bool down = false;
  @override
  Widget build(BuildContext c) {
    final on = widget.onTap != null, pr = widget.primary, sel = widget.selected;
    final fg = !on ? C.ink3 : pr ? Colors.white : C.ink;
    final pressed = down || sel;
    return MouseRegion(
      cursor: on ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: on ? (_) => setState(() => down = true) : null,
        onTapCancel: () => setState(() => down = false),
        onTapUp: (_) => setState(() => down = false),
        onTap: widget.onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: widget.compact ? 28 : 36),
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 10 : 16, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: pr && on ? C.accentLo : C.edge),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: pr && on ? (pressed ? [C.accentLo, C.accent] : [C.accentHi, C.accentLo]) : sel ? [C.lo.withValues(alpha: .55), C.chrome2] : pressed ? [C.chrome2, C.chrome] : [Colors.white, C.chrome2]),
            boxShadow: pressed ? null : [const BoxShadow(color: Color(0x33000000), blurRadius: 1, offset: Offset(0, 1))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (widget.icon != null) ...[Icon(widget.icon, size: 16, color: fg), const SizedBox(width: 6)],
            Flexible(child: Text(widget.label, textAlign: TextAlign.center, style: ui(widget.compact ? 12 : 13, w: FontWeight.w600, c: fg, h: 1.2))),
          ]),
        ),
      ),
    );
  }
}

/// Green LCD read-out.
class Lcd extends StatelessWidget {
  final String value, label; final double size;
  const Lcd(this.value, {super.key, this.label = '', this.size = 28});
  @override
  Widget build(BuildContext c) => Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: C.lcd, border: _bevelIn, boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 2), blurStyle: BlurStyle.inner)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (label.isNotEmpty) Align(alignment: Alignment.centerLeft, child: Text(label, style: mono(10, c: C.lcdInk.withValues(alpha: .7)))),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: mono(size, w: FontWeight.w600, c: C.lcdInk))),
        ]),
      );
}

class Caption extends StatelessWidget {
  final String text; const Caption(this.text, {super.key});
  @override
  Widget build(BuildContext c) => Padding(padding: const EdgeInsets.only(top: 12, bottom: 6), child: Text(text.toUpperCase(), style: ui(11, w: FontWeight.w700, c: C.ink3, ls: .8)));
}

class Para extends StatelessWidget {
  final String text; final Color? color; const Para(this.text, {super.key, this.color});
  @override
  Widget build(BuildContext c) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Text(text, style: ui(14, c: color ?? C.ink2, h: 1.6)));
}

class Note extends StatelessWidget {
  final String text; final bool ok; final bool warn;
  const Note(this.text, {super.key, this.ok = false, this.warn = false});
  @override
  Widget build(BuildContext c) {
    final col = ok ? C.ok : warn ? C.amber : C.ink2;
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: ok ? C.okWash : warn ? C.amberWash : C.stripe, border: Border(left: BorderSide(color: col, width: 4), top: const BorderSide(color: C.lo), right: const BorderSide(color: C.lo), bottom: const BorderSide(color: C.lo))),
      child: Text(text, style: ui(13, c: C.ink, h: 1.45)),
    );
  }
}

/// Two columns on wide screens, a single stack on phones.
class Cols extends StatelessWidget {
  final List<Widget> a, b; final int fa, fb; final double breakAt;
  const Cols({super.key, required this.a, required this.b, this.fa = 1, this.fb = 1, this.breakAt = 900});
  @override
  Widget build(BuildContext c) => LayoutBuilder(builder: (c, bc) {
        if (bc.maxWidth < breakAt) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...a, ...b]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: fa, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: a)),
          const SizedBox(width: 16),
          Expanded(flex: fb, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: b)),
        ]);
      });
}

class Clock extends StatefulWidget { const Clock({super.key}); @override State<Clock> createState() => _ClockS(); }
class _ClockS extends State<Clock> {
  late Timer t;
  @override
  void initState() { super.initState(); t = Timer.periodic(const Duration(seconds: 20), (_) => setState(() {})); }
  @override
  void dispose() { t.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext c) {
    final n = DateTime.now();
    return Text('${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}', style: mono(12, c: C.ink2));
  }
}
