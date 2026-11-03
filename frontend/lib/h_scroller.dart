import 'package:flutter/material.dart';

class HScroller extends StatefulWidget {
  const HScroller({super.key, required this.height, required this.children});
  final double height;
  final List<Widget> children;

  @override
  State<HScroller> createState() => _HScrollerState();
}

class _HScrollerState extends State<HScroller> {
  final _c = ScrollController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _scrollBy(double dx) {
    if (!_c.hasClients) return;
    final target =
        (_c.offset + dx).clamp(0.0, _c.position.maxScrollExtent).toDouble();
    _c.animateTo(target,
        duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 560;
        return SizedBox(
          height: widget.height,
          child: Stack(
            children: [
              ListView(
                controller: _c,
                scrollDirection: Axis.horizontal,
                children: widget.children,
              ),
              if (wide) ...[
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _Arrow(
                      icon: Icons.chevron_left_rounded,
                      onTap: () => _scrollBy(-280),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _Arrow(
                      icon: Icons.chevron_right_rounded,
                      onTap: () => _scrollBy(280),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 3,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 22),
        ),
      ),
    );
  }
}