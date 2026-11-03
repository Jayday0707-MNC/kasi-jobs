import 'package:flutter/material.dart';
import 'api.dart';
import 'category_style.dart';
import 'employer_state.dart';
import 'models.dart';
import 'my_jobs_screen.dart';
import 'page_header.dart';
import 'theme.dart';

class EmployerDashboard extends StatefulWidget {
  const EmployerDashboard({super.key, required this.onVerify});
  final VoidCallback onVerify;

  @override
  State<EmployerDashboard> createState() => _EmployerDashboardState();
}

class _EmployerDashboardState extends State<EmployerDashboard> {
  List<Job> jobs = [];
  bool loadingJobs = true;
  String? jobsError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => employerState.load());
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() {
      loadingJobs = true;
      jobsError = null;
    });
    try {
      final data = await Api.myJobs();
      if (mounted) setState(() => jobs = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => jobsError = e.message);
    } catch (_) {
      if (mounted) setState(() => jobsError = 'Could not reach the server.');
    } finally {
      if (mounted) setState(() => loadingJobs = false);
    }
  }

  Future<void> _refresh() async {
    await employerState.load();
    await _loadJobs();
  }

  Future<void> _post() async {
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PostJobScreen()),
    );
    if (posted == true) _loadJobs();
  }

  Widget _jobsSection(EmployerInfo info) {
    final cs = Theme.of(context).colorScheme;
    if (loadingJobs) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (jobsError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(jobsError!, style: TextStyle(color: cs.error)),
      );
    }
    if (jobs.isEmpty) {
      return Card(
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
                    color: cs.primaryContainer.withValues(alpha: 0.7),
                  ),
                  child: Icon(
                    info.verified
                        ? Icons.work_outline_rounded
                        : Icons.lock_outline_rounded,
                    size: 34,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  info.verified ? 'No jobs yet' : 'Posting is locked',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  info.verified
                      ? 'Post your first job to start finding people.'
                      : 'Get verified first, then you can post jobs here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < jobs.length; i++)
          FadeIn(index: i, child: _JobTile(jobs[i])),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: ListenableBuilder(
        listenable: employerState,
        builder: (context, _) {
          final info = employerState.info;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PageHeader(
                title: info?.businessName ?? 'My business',
                subtitle: 'Your jobs and verification status',
                trailing: IconButton(
                  tooltip: 'Refresh',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
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
                        if (info == null)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: employerState.error != null
                                  ? Text(employerState.error!,
                                      style: TextStyle(color: cs.error))
                                  : const CircularProgressIndicator(),
                            ),
                          )
                        else ...[
                          FadeIn(
                            child: StatusBanner(
                              info,
                              action: info.verified
                                  ? null
                                  : FilledButton.tonal(
                                      onPressed: widget.onVerify,
                                      child: Text(info.status == 'needs_documents'
                                          ? 'Upload documents'
                                          : 'Open verification'),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Text('My jobs',
                                    style: text.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800)),
                              ),
                              if (info.verified)
                                FilledButton.icon(
                                  onPressed: _post,
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Post a job'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _jobsSection(info),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile(this.job);
  final Job job;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final (label, color) = switch (job.status) {
      'approved' => ('Live', kEmerald),
      'pending' => ('Waiting for approval', kAmber),
      'rejected' => ('Not approved', kCoral),
      _ => (job.status, cs.outline),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategoryBadge(job.category),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.title,
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${job.area}  ·  ${job.category}',
                      style: text.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant)),
                  if (job.closingDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('Closes ${isoDate(job.closingDate!)}',
                          style: text.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      label,
                      style: text.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: job.status == 'pending'
                            ? const Color(0xFF8A5A00)
                            : color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}