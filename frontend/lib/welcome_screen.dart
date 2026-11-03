import 'package:flutter/material.dart';
import 'auth_screen.dart';
import 'session.dart';
import 'theme.dart';
import 'blobs.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
           body: GradientBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Reveal(
                      0,
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: kAmber,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.work_rounded,
                              color: Color(0xFF2B1B00),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Kasi Jobs',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 56),
                    const _Reveal(
                      1,
                      Text(
                        'Work near you,\nstraight to your phone.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _Reveal(
                      2,
                      Text(
                        'Jobs, learnerships and seasonal work around Piet Retief (eMkhondo), all in one place.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const _Reveal(
                      3,
                      _Feature(
                        Icons.place_rounded,
                        'Local jobs only',
                        'Filter by your township or village.',
                      ),
                    ),
                    const _Reveal(
                      4,
                      _Feature(
                        Icons.notifications_active_rounded,
                        'Save your alerts',
                        'Choose the work and areas you care about.',
                      ),
                    ),
                    const _Reveal(
                      5,
                      _Feature(
                        Icons.bolt_rounded,
                        'Light on data',
                        'Built to be fast on any phone.',
                      ),
                    ),
                    const SizedBox(height: 36),
                    _Reveal(
                      6,
                      Column(
                        children: [
                          FilledButton(
                            onPressed: onDone,
                            style: FilledButton.styleFrom(
                              backgroundColor: kAmber,
                              foregroundColor: const Color(0xFF2B1B00),
                              minimumSize: const Size.fromHeight(56),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            child: const Text('Browse jobs'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AuthScreen(),
                                ),
                              );
                              if (session.loggedIn) onDone();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              minimumSize: const Size.fromHeight(56),
                            ),
                            child: const Text('Sign in or create account'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal(this.index, this.child);
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + index * 130),
      curve: Curves.easeOutCubic,
      builder: (context, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 20), child: c),
      ),
      child: child,
    );
  }
}
