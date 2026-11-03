import 'package:flutter/material.dart';
import 'api.dart';
import 'category_style.dart';
import 'guest_view.dart';
import 'models.dart';
import 'page_header.dart';
import 'session.dart';
import 'theme.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: session,
        builder: (context, _) => session.loggedIn
            ? const _AlertsBody()
            : const GuestView(
                pageTitle: 'My alerts',
                icon: Icons.notifications_active_rounded,
                title: 'Get alerts for your area',
                message:
                    'Create a free account to save the work and areas you care about.',
              ),
      ),
    );
  }
}

class _AlertsBody extends StatefulWidget {
  const _AlertsBody();

  @override
  State<_AlertsBody> createState() => _AlertsBodyState();
}

class _AlertsBodyState extends State<_AlertsBody> {
  List<Sub> subs = [];
  List<Option> areas = [];
  List<Option> categories = [];
  int? areaId;
  int? categoryId;
  int resetKey = 0;
  bool loading = true;
  bool adding = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final s = await Api.subscriptions();
      final a = await Api.options('/areas');
      final c = await Api.options('/categories');
      if (!mounted) return;
      setState(() {
        subs = s;
        areas = a;
        categories = c;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not reach the server. Is the backend running?');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _add() async {
    if (areaId == null || categoryId == null) {
      setState(() => error = 'Choose an area and a type of work first.');
      return;
    }
    setState(() {
      adding = true;
      error = null;
    });
    try {
      await Api.subscribe(categoryId!, areaId!);
      areaId = null;
      categoryId = null;
      resetKey++;
      subs = await Api.subscriptions();
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not reach the server.';
    }
    if (mounted) setState(() => adding = false);
  }

  Future<void> _remove(Sub s) async {
    try {
      await Api.unsubscribe(s.id);
      subs.removeWhere((x) => x.id == s.id);
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not reach the server.';
    }
    if (mounted) setState(() {});
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (loading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          color: cs.primary,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My alerts',
                        style: text.headlineSmall?.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Choose the work and areas you want to hear about.',
                        style: TextStyle(color: cs.onPrimary)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notifications_active_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text('${subs.length}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kAmber.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: kAmber.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_rounded,
                            color: dark ? kAmber : const Color(0xFF8A5A00)),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Your alerts are saved. SMS and email sending will be switched on soon.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('Your alerts',
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  if (subs.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cs.primaryContainer
                                      .withValues(alpha: 0.7),
                                ),
                                child: Icon(
                                    Icons.notifications_none_rounded,
                                    size: 36,
                                    color: cs.primary),
                              ),
                              const SizedBox(height: 14),
                              Text('No alerts yet',
                                  style: text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text('Add one below to get started.',
                                  style:
                                      TextStyle(color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < subs.length; i++)
                      Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CategoryBadge(subs[i].category),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(subs[i].category,
                                          style: text.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.place_rounded,
                                              size: 16,
                                              color: cs.onSurfaceVariant),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(subs[i].area,
                                                style: TextStyle(
                                                    color:
                                                        cs.onSurfaceVariant)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove',
                                  icon: Icon(Icons.delete_outline_rounded,
                                      color: cs.error),
                                  onPressed: () => _remove(subs[i]),
                                ),
                              ],
                            ),
                          ),
                        ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add an alert',
                              style: text.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('Pick a type of work and an area.',
                              style: TextStyle(color: cs.onSurfaceVariant)),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int>(
                            key: ValueKey('cat-$resetKey'),
                            initialValue: categoryId,
                            decoration:
                                _dec('Type of work', Icons.category_rounded),
                            items: [
                              for (final c in categories)
                                DropdownMenuItem(
                                    value: c.id, child: Text(c.name)),
                            ],
                            onChanged: (v) => categoryId = v,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            key: ValueKey('area-$resetKey'),
                            initialValue: areaId,
                            decoration: _dec('Area', Icons.place_rounded),
                            items: [
                              for (final a in areas)
                                DropdownMenuItem(
                                    value: a.id, child: Text(a.name)),
                            ],
                            onChanged: (v) => areaId = v,
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 12),
                            Text(error!, style: TextStyle(color: cs.error)),
                          ],
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: adding ? null : _add,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add alert'),
                            style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52)),
                          ),
                        ],
                      ),
                    ),
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