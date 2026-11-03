import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'category_style.dart';
import 'models.dart';
import 'page_header.dart';
import 'theme.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> employers = [];
  List<Job> jobs = [];
  bool loading = true;
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
      final e = await Api.pendingEmployers();
      final j = await Api.pendingJobs();
      if (!mounted) return;
      setState(() {
        employers = e;
        jobs = j;
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

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _act(Future<void> Function() action, String done) async {
    String message = done;
    try {
      await action();
    } on ApiException catch (e) {
      message = e.message;
    } catch (_) {
      message = 'Could not reach the server.';
    }
    _snack(message);
    await _load();
  }

  Future<void> _view(int docId) async {
    try {
      final url = await Api.documentUrl(docId);
      final ok = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (!ok) _snack('Could not open the document.');
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not open the document.');
    }
  }

  Future<void> _reject(Map<String, dynamic> e) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send documents back'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Tell them what to fix, e.g. The ID photo is blurry',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final t = controller.text.trim();
              if (t.length >= 5) Navigator.pop(ctx, t);
            },
            child: const Text('Send back'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;
    await _act(
      () => Api.rejectEmployer(e['id'] as int, reason),
      'Documents sent back to the employer',
    );
  }

  Widget _employerCard(Map<String, dynamic> e) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final docs = (e['documents'] as List).cast<Map<String, dynamic>>();
    final email = e['email'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: kViolet.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child:
                      const Icon(Icons.business_center_rounded, color: kViolet),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e['business_name'] as String,
                          style: text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text('${e['contact_name']}  ·  ${e['phone']}',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                      if (email != null)
                        Text(email,
                            style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Documents',
                style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (final d in docs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.description_rounded,
                        size: 20, color: cs.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d['label'] as String,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          Text(d['filename'] as String,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 12)),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _view(d['id'] as int),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('View'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _reject(e),
                  child: const Text('Send back'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _act(
                    () => Api.verifyEmployer(e['id'] as int),
                    'Employer verified',
                  ),
                  child: const Text('Verify'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _jobCard(Job j) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryBadge(j.category, size: 46),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(j.title,
                          style: text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text('${j.employer}  ·  ${j.area}',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            if (j.pay != null) ...[
              const SizedBox(height: 8),
              Text(j.pay!, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 8),
            Text(j.description, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () =>
                      _act(() => Api.rejectJob(j.id), 'Job rejected'),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () =>
                      _act(() => Api.approveJob(j.id), 'Job approved and live'),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PageHeader(
            title: 'Admin',
            subtitle:
                '${employers.length} to verify  ·  ${jobs.length} jobs waiting',
            trailing: IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : error != null
                        ? Text(error!, style: TextStyle(color: cs.error))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Employers to verify',
                                  style: text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 12),
                              if (employers.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                      'Nobody is waiting for verification.',
                                      style: TextStyle(
                                          color: cs.onSurfaceVariant)),
                                ),
                              for (final e in employers) _employerCard(e),
                              const SizedBox(height: 20),
                              Text('Jobs to approve',
                                  style: text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 12),
                              if (jobs.isEmpty)
                                Text('No jobs are waiting.',
                                    style: TextStyle(
                                        color: cs.onSurfaceVariant)),
                              for (final j in jobs) _jobCard(j),
                            ],
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}