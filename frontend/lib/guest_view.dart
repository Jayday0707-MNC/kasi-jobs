import 'package:flutter/material.dart';
import 'auth_screen.dart';
import 'page_header.dart';
import 'theme.dart';

class GuestView extends StatelessWidget {
  const GuestView({
    super.key,
    required this.pageTitle,
    required this.icon,
    required this.title,
    required this.message,
  });
  final String pageTitle;
  final IconData icon;
  final String title;
  final String message;

  void _open(BuildContext context, bool register) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AuthScreen(startOnRegister: register)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Text(
            pageTitle,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 40),
              child: Column(
                children: [
                  _FloatingIcon(icon),
                  const SizedBox(height: 28),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: () => _open(context, true),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54)),
                    child: const Text('Create free account'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _open(context, false),
                    child: const Text('I already have an account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FloatingIcon extends StatefulWidget {
  const _FloatingIcon(this.icon);
  final IconData icon;

  @override
  State<_FloatingIcon> createState() => _FloatingIconState();
}

class _FloatingIconState extends State<_FloatingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -8 * Curves.easeInOut.transform(_c.value)),
        child: child,
      ),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kViolet, kSky],
          ),
          boxShadow: [
            BoxShadow(
              color: kViolet.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(widget.icon, color: Colors.white, size: 44),
      ),
    );
  }
}