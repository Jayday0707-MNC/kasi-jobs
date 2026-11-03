import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'category_style.dart';
import 'models.dart';
import 'session.dart';
import 'theme.dart';
import 'auth_screen.dart';
import 'blobs.dart';
import 'h_scroller.dart';


String closesText(int days) => days <= 0
    ? 'Closes today'
    : days == 1
    ? 'Closes tomorrow'
    : 'Closes in $days days';

String _greeting() {
  final h = DateTime.now().hour;
  final part = h < 12
      ? 'Good morning'
      : h < 17
      ? 'Good afternoon'
      : 'Good evening';
  final name = (session.user?['full_name'] as String?)?.trim();
  if (name == null || name.isEmpty) return part;
  return '$part, ${name.split(' ').first}';
}

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  List<Option> areas = [];
  List<Option> categories = [];
  List<Job> jobs = [];
  int? areaId;
  int? categoryId;
  String query = '';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final results = await Future.wait([
        Api.options('/areas'),
        Api.options('/categories'),
      ]);
      areas = results[0];
      categories = results[1];
    } catch (_) {}
    await _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await Api.jobs(areaId: areaId, categoryId: categoryId);
      if (!mounted) return;
      setState(() {
        jobs = data;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Could not reach the server. Is the backend running?';
        loading = false;
      });
    }
  }

  List<Job> get visible {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return jobs;
    return jobs
        .where(
          (j) =>
              j.title.toLowerCase().contains(q) ||
              j.employer.toLowerCase().contains(q) ||
              j.description.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final list = visible;

    Widget results;
    if (loading) {
      results = Column(
        children: List.generate(4, (_) => const _SkeletonCard()),
      );
    } else if (error != null) {
      results = _EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'No connection',
        message: error!,
        action: OutlinedButton(
          onPressed: _loadJobs,
          child: const Text('Try again'),
        ),
      );
    } else if (list.isEmpty) {
      results = const _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No jobs found',
        message: 'Try another area or type of work.',
      );
    } else {
      results = Column(
        children: [
          for (var i = 0; i < list.length; i++)
            _FadeIn(index: i, child: _JobCard(list[i])),
        ],
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadJobs,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Hero(
              onSearch: (v) => setState(() => query = v),
              onRefresh: _loadJobs,
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _JoinBanner(),
                      Text(
                        'Type of work',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CategoryRow(
                        categories: categories,
                        selected: categoryId,
                        onSelected: (id) {
                          categoryId = id;
                          _loadJobs();
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Area',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _AreaChips(
                        areas: areas,
                        selected: areaId,
                        onSelected: (id) {
                          areaId = id;
                          _loadJobs();
                        },
                      ),
                      const SizedBox(height: 16),
                      if (!loading && error == null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '${list.length} ${list.length == 1 ? 'job' : 'jobs'} available',
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      results,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _openAuth(BuildContext context, {required bool register}) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => AuthScreen(startOnRegister: register)),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onSearch, required this.onRefresh});
  final ValueChanged<String> onSearch;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: GradientBackdrop(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: kAmber,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.work_rounded,
                            size: 20,
                            color: Color(0xFF2B1B00),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Kasi Jobs',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        ListenableBuilder(
                          listenable: session,
                          builder: (context, _) {
                            if (session.loggedIn) {
                              final name =
                                  (session.user?['full_name'] as String?) ?? '';
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Refresh',
                                    onPressed: onRefresh,
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.22,
                                    ),
                                    child: Text(
                                      name.isEmpty
                                          ? '?'
                                          : name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      _openAuth(context, register: false),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  child: const Text('Sign in'),
                                ),
                                const SizedBox(width: 4),
                                FilledButton(
                                  onPressed: () =>
                                      _openAuth(context, register: true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: kAmber,
                                    foregroundColor: const Color(0xFF2B1B00),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('Join free'),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    ListenableBuilder(
                      listenable: session,
                      builder: (context, _) => Text(
                        _greeting(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Find work near\nPiet Retief',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      onChanged: onSearch,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search jobs, e.g. driver',
                        hintStyle: const TextStyle(color: Colors.black45),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Colors.black54,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
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

class _JoinBanner extends StatelessWidget {
  const _JoinBanner();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (session.loggedIn) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kViolet, kSky],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Never miss a job',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Create a free account and save the areas and work you care about.',
                        style: TextStyle(color: Colors.white70, height: 1.35),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: () => _openAuth(context, register: true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: kViolet,
                        ),
                        child: const Text('Create free account'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });
  final List<Option> categories;
  final int? selected;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return HScroller(
      height: 100,
      children: [
        _CategoryTile(
          icon: Icons.apps_rounded,
          label: 'All',
          color: cs.primary,
          selected: selected == null,
          onTap: () => onSelected(null),
        ),
        for (final c in categories)
          _CategoryTile(
            icon: categoryIcon(c.name),
            label: shortCategory(c.name),
            color: categoryColor(c.name),
            selected: selected == c.id,
            onTap: () => onSelected(c.id),
          ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: 88,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: selected
                  ? cs.primary
                  : (Theme.of(context).cardTheme.color ?? cs.surface),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? cs.primary
                    : cs.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.2)
                        : color.withValues(alpha: 0.14),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: selected ? Colors.white : color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? cs.onPrimary : cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class _AreaChips extends StatelessWidget {
  const _AreaChips({
    required this.areas,
    required this.selected,
    required this.onSelected,
  });
  final List<Option> areas;
  final int? selected;
  final ValueChanged<int?> onSelected;

  Widget _chip(String label, bool isSelected, VoidCallback tap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => tap(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return HScroller(
      height: 44,
      children: [
        _chip('All areas', selected == null, () => onSelected(null)),
        for (final a in areas)
          _chip(a.name, selected == a.id, () => onSelected(a.id)),
      ],
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
      duration: Duration(milliseconds: 350 + (index > 8 ? 8 : index) * 70),
      curve: Curves.easeOutCubic,
      builder: (context, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: c),
      ),
      child: child,
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final base = cs.onSurface.withValues(alpha: 0.06 + 0.06 * _c.value);
        Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(6),
          ),
        );
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(170, 16),
                    const SizedBox(height: 8),
                    bar(110, 12),
                    const SizedBox(height: 12),
                    bar(140, 12),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primaryContainer.withValues(alpha: 0.6),
              ),
              child: Icon(icon, size: 40, color: cs.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge(this.category, {this.size = 52});
  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(categoryIcon(category), color: color, size: size * 0.5),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text, {this.strong = false});
  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = strong ? cs.primary : cs.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kAmber.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: dark ? kAmber : const Color(0xFF8A5A00),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard(this.job);
  final Job job;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final days = job.daysLeft;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetails(context, job),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CategoryBadge(job.category),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      job.employer,
                      style: text.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Meta(Icons.place_rounded, job.area),
                        if (job.pay != null)
                          _Meta(Icons.payments_rounded, job.pay!, strong: true),
                        if (days != null && days <= 7) _Badge(closesText(days)),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }
}

void _showDetails(BuildContext context, Job job) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => _JobSheet(job),
  );
}

class _JobSheet extends StatefulWidget {
  const _JobSheet(this.job);
  final Job job;

  @override
  State<_JobSheet> createState() => _JobSheetState();
}

class _JobSheetState extends State<_JobSheet> {
  bool copied = false;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final days = job.daysLeft;
    final apply = job.howToApply ?? 'Contact the employer.';

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          Row(
            children: [
              _CategoryBadge(job.category, size: 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      job.employer,
                      style: text.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _Meta(Icons.place_rounded, job.area),
              _Meta(categoryIcon(job.category), job.category),
              if (days != null) _Meta(Icons.event_rounded, closesText(days)),
            ],
          ),
          if (job.pay != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(Icons.payments_rounded, color: cs.primary),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pay', style: text.labelMedium),
                      Text(
                        job.pay!,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          section('About the job'),
          Text(job.description, style: text.bodyLarge?.copyWith(height: 1.45)),
          section('How to apply'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(apply, style: text.bodyLarge),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: apply));
              if (mounted) setState(() => copied = true);
            },
            icon: Icon(copied ? Icons.check_rounded : Icons.copy_rounded),
            label: Text(copied ? 'Copied' : 'Copy how to apply'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }
}
