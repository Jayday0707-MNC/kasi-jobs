import 'package:flutter/material.dart';
import 'api.dart';
import 'models.dart';
import 'theme.dart';

String two(int n) => n.toString().padLeft(2, '0');
String isoDate(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

class MyJobsScreen extends StatefulWidget {
  const MyJobsScreen({super.key});

  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {
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
      final data = await Api.myJobs();
      if (!mounted) return;
      setState(() => jobs = data);
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

  Future<void> _post() async {
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PostJobScreen()),
    );
    if (posted == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget body;
    if (loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (error != null) {
      body = Center(child: Text(error!));
    } else if (jobs.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.work_outline, size: 48, color: cs.outline),
              const SizedBox(height: 12),
              const Text('You have not posted any jobs yet.',
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          for (final j in jobs) _MyJobCard(j),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My jobs',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _post,
        icon: const Icon(Icons.add),
        label: const Text('Post a job'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'New jobs go live once an admin has checked them.',
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyJobCard extends StatelessWidget {
  const _MyJobCard(this.job);
  final Job job;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final (label, color) = switch (job.status) {
      'approved' => ('Live', Colors.green.shade700),
      'pending' => ('Waiting for approval', kAmber),
      'rejected' => ('Not approved', cs.error),
      _ => (job.status, cs.outline),
    };

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(job.title,
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(label,
                      style: text.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700, color: color)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${job.area}  ·  ${job.category}',
                style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            if (job.closingDate != null) ...[
              const SizedBox(height: 4),
              Text('Closes ${isoDate(job.closingDate!)}',
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  final pay = TextEditingController();
  final howToApply = TextEditingController();

  List<Option> areas = [];
  List<Option> categories = [];
  int? areaId;
  int? categoryId;
  DateTime? closing;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final a = await Api.options('/areas');
      final c = await Api.options('/categories');
      if (mounted) {
        setState(() {
          areas = a;
          categories = c;
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Could not load areas and categories.');
    }
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    pay.dispose();
    howToApply.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: closing ?? now.add(const Duration(days: 14)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null) setState(() => closing = d);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Api.createJob({
        'title': title.text.trim(),
        'description': description.text.trim(),
        'category_id': categoryId,
        'area_id': areaId,
        if (pay.text.trim().isNotEmpty) 'pay': pay.text.trim(),
        if (howToApply.text.trim().isNotEmpty)
          'how_to_apply': howToApply.text.trim(),
        if (closing != null) 'closing_date': isoDate(closing!),
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not reach the server.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Post a job')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextFormField(
                  controller: title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _dec('Job title', hint: 'e.g. General worker'),
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Enter a job title'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: categoryId,
                  decoration: _dec('Type of work'),
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => categoryId = v,
                  validator: (v) => v == null ? 'Choose a type of work' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: areaId,
                  decoration: _dec('Where is the job?'),
                  items: [
                    for (final a in areas)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => areaId = v,
                  validator: (v) => v == null ? 'Choose an area' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: description,
                  minLines: 4,
                  maxLines: 8,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _dec('About the job',
                      hint: 'What will the person do? What do they need?'),
                  validator: (v) => (v == null || v.trim().length < 10)
                      ? 'Write at least 10 characters'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: pay,
                  decoration: _dec('Pay (optional)', hint: 'e.g. R4 500 per month'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: howToApply,
                  minLines: 2,
                  maxLines: 4,
                  decoration: _dec('How to apply (optional)',
                      hint: 'Phone number, address or who to ask for'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(closing == null
                      ? 'Closing date (optional)'
                      : 'Closes ${isoDate(closing!)}'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: TextStyle(color: cs.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : _submit,
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  child: busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Submit for approval'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}