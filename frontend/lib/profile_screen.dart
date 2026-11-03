import 'package:flutter/material.dart';
import 'api.dart';
import 'guest_view.dart';
import 'page_header.dart';
import 'session.dart';
import 'theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: session,
        builder: (context, _) => session.loggedIn
            ? const _ProfileBody()
            : const GuestView(
                pageTitle: 'Profile',
                icon: Icons.person_rounded,
                title: 'Your Kasi Jobs profile',
                message:
                    'Create an account to save alerts and keep your details in one place.',
              ),
      ),
    );
  }
}

String _roleLabel(String role) => switch (role) {
      'employer' => 'Employer',
      'admin' => 'Administrator',
      _ => 'Job seeker',
    };

class _ProfileBody extends StatefulWidget {
  const _ProfileBody();

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  String? areaName;

  @override
  void initState() {
    super.initState();
    _loadArea();
  }

  Future<void> _loadArea() async {
    final id = session.user?['area_id'] as int?;
    if (id == null) return;
    try {
      final areas = await Api.options('/areas');
      final match = areas.where((a) => a.id == id);
      if (match.isNotEmpty && mounted) setState(() => areaName = match.first.name);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final u = session.user!;
    final cs = Theme.of(context).colorScheme;
    final name = (u['full_name'] as String?) ?? '';
    final role = (u['role'] as String?) ?? 'seeker';
    final phone = (u['phone'] as String?) ?? '';
    final email = u['email'] as String?;
    final sms = (u['consent_sms'] as bool?) ?? false;
    final mail = (u['consent_email'] as bool?) ?? false;
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [kGreen, Color(0xFF43A875)]),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [kAmber, kCoral]),
                ),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.white,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: kGreen,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _roleLabel(role),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(
                children: [
                  _FadeIn(
                    index: 0,
                    child: _Section(
                      title: 'Contact details',
                      children: [
                        _InfoRow(
                          icon: Icons.phone_rounded,
                          color: kCoral,
                          label: 'Phone',
                          value: phone,
                        ),
                        _InfoRow(
                          icon: Icons.email_rounded,
                          color: kSky,
                          label: 'Email',
                          value: email ?? 'No email added',
                        ),
                        _InfoRow(
                          icon: Icons.place_rounded,
                          color: kViolet,
                          label: 'Area',
                          value: areaName ?? 'Not set',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FadeIn(
                    index: 1,
                    child: _Section(
                      title: 'Alert preferences',
                      children: [
                        _ToggleRow(
                          icon: Icons.sms_rounded,
                          color: kEmerald,
                          label: 'SMS alerts',
                          on: sms,
                        ),
                        _ToggleRow(
                          icon: Icons.mark_email_read_rounded,
                          color: kAmber,
                          label: 'Email alerts',
                          on: mail,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Changing these in the app is coming soon.',
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _FadeIn(
                    index: 2,
                    child: OutlinedButton.icon(
                      onPressed: () => session.clear(),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                        minimumSize: const Size.fromHeight(54),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Kasi Jobs  ·  Piet Retief (eMkhondo)',
                    style: TextStyle(color: cs.outline, fontSize: 12),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile(this.icon, this.color);
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          _IconTile(icon, color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.on,
  });
  final IconData icon;
  final Color color;
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          _IconTile(icon, color),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: on
                  ? kEmerald.withValues(alpha: 0.18)
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              on ? 'On' : 'Off',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: on ? const Color(0xFF138A52) : cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + index * 100),
      curve: Curves.easeOut,
      builder: (context, opacity, child) => Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - opacity)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}