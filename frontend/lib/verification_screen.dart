import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'api.dart';
import 'employer_state.dart';
import 'models.dart';
import 'page_header.dart';
import 'theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

const _hints = {
  'owner_id': 'ID card or passport. A clear photo or scan.',
  'business_proof':
      'CIPC certificate. For informal businesses, farms or sole traders: a letter from your ward councillor, a SARS letter, or a photo of your premises.',
  'address_proof': 'Utility bill or lease agreement, not older than 3 months.',
};

const _icons = {
  'owner_id': Icons.badge_rounded,
  'business_proof': Icons.storefront_rounded,
  'address_proof': Icons.home_work_rounded,
};

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  String? busyType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => employerState.load());
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pick(String type) async {
    dynamic result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true,
        withReadStream: !kIsWeb,
      );
    } catch (e) {
      _toast('Could not open the file picker: $e');
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;

    List<int>? bytes = f.bytes;
    if (bytes == null && f.readStream != null) {
      final data = <int>[];
      await for (final chunk in f.readStream!) {
        data.addAll(chunk);
        if (data.length > 5 * 1024 * 1024) break;
      }
      bytes = data;
    }
    if (bytes == null || bytes.isEmpty) {
      _toast(
        'Could not read "${f.name}" (${f.size} bytes). Save it on this device and pick it again.',
      );
      return;
    }
    if (bytes.length > 5 * 1024 * 1024) {
      _toast('That file is too large (maximum 5 MB).');
      return;
    }

    setState(() => busyType = type);
    try {
      await Api.uploadDocument(type, bytes, f.name);
      await employerState.load();
      _toast('Uploaded');
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not upload. Check your connection.');
    }
    if (mounted) setState(() => busyType = null);
  }

  Future<void> _remove(EmployerDoc doc) async {
    try {
      await Api.deleteDocument(doc.id);
      await employerState.load();
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not remove the file.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: ListenableBuilder(
        listenable: employerState,
        builder: (context, _) {
          final info = employerState.info;
          final uploaded = info?.uploaded ?? 0;
          final total = info?.required.length ?? 3;

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PageHeader(
                title: 'Verification',
                subtitle:
                    'Upload your documents so an admin can verify your business.',
                trailing: IconButton(
                  tooltip: 'Refresh',
                  onPressed: employerState.load,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : uploaded / total,
                        minHeight: 10,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(kAmber),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$uploaded of $total documents uploaded',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
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
                    child: info == null
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: employerState.error != null
                                  ? Text(
                                      employerState.error!,
                                      style: TextStyle(color: cs.error),
                                    )
                                  : const CircularProgressIndicator(),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FadeIn(child: StatusBanner(info)),
                              const SizedBox(height: 20),
                              for (var i = 0; i < info.required.length; i++)
                                FadeIn(
                                  index: i + 1,
                                  child: _DocCard(
                                    required: info.required[i],
                                    doc: info.docFor(info.required[i].type),
                                    verified: info.verified,
                                    busy: busyType == info.required[i].type,
                                    onPick: () => _pick(info.required[i].type),
                                    onRemove: _remove,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.lock_rounded,
                                    size: 18,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Your documents are private. Only the Kasi Jobs admin can open them, and job seekers never see them. Accepted: PDF, JPG or PNG, up to 5 MB each.',
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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

class _DocCard extends StatelessWidget {
  const _DocCard({
    required this.required,
    required this.doc,
    required this.verified,
    required this.busy,
    required this.onPick,
    required this.onRemove,
  });
  final RequiredDoc required;
  final EmployerDoc? doc;
  final bool verified;
  final bool busy;
  final VoidCallback onPick;
  final Future<void> Function(EmployerDoc) onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final d = doc;

    final (label, color) = switch (d?.status) {
      'approved' => ('Approved', kEmerald),
      'pending' => ('Waiting for review', kAmber),
      'rejected' => ('Rejected', kCoral),
      _ => ('Not uploaded', cs.outline),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: kViolet.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _icons[required.type] ?? Icons.description_rounded,
                    color: kViolet,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        required.label,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _hints[required.type] ?? '',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    style: text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: d?.status == 'pending'
                          ? const Color(0xFF8A5A00)
                          : color,
                    ),
                  ),
                ),
                if (d != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(
                      d.filename,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
            if (d?.status == 'rejected' &&
                (d?.reviewNote ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kCoral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Admin note: ${d!.reviewNote}'),
              ),
            ],
            if (!verified) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : onPick,
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_rounded),
                    label: Text(d == null ? 'Upload' : 'Replace'),
                  ),
                  if (d != null && d.status != 'approved') ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: busy ? null : () => onRemove(d),
                      icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
