import 'package:flutter/material.dart';
import 'api.dart';
import 'models.dart';
import 'theme.dart';

class EmployerState extends ChangeNotifier {
  EmployerInfo? info;
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      info = await Api.employerMe();
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not reach the server. Is the backend running?';
    }
    loading = false;
    notifyListeners();
  }

  void reset() {
    info = null;
    error = null;
    loading = false;
  }
}

final employerState = EmployerState();

({String label, Color color, IconData icon, String title, String message})
    statusInfo(EmployerInfo i) {
  switch (i.status) {
    case 'verified':
      return (
        label: 'Verified',
        color: kEmerald,
        icon: Icons.verified_rounded,
        title: 'Business verified',
        message:
            'You can post jobs. Each job is checked by an admin before it goes live.',
      );
    case 'in_review':
      return (
        label: 'In review',
        color: kAmber,
        icon: Icons.hourglass_top_rounded,
        title: 'Documents under review',
        message:
            'An admin is checking your documents. Job posting unlocks as soon as you are verified.',
      );
    case 'changes_needed':
      final notes = i.documents
          .where((d) => d.status == 'rejected' && (d.reviewNote ?? '').isNotEmpty)
          .map((d) => d.reviewNote!)
          .toList();
      return (
        label: 'Changes needed',
        color: kCoral,
        icon: Icons.error_rounded,
        title: 'Changes needed',
        message: notes.isEmpty
            ? 'Please check your documents and upload them again.'
            : 'The admin said: ${notes.first}',
      );
    default:
      return (
        label: 'Not submitted',
        color: kViolet,
        icon: Icons.upload_file_rounded,
        title: 'Upload your documents',
        message:
            'Add the 3 documents so we can verify your business. You cannot post jobs until you are verified.',
      );
  }
}

class StatusBanner extends StatelessWidget {
  const StatusBanner(this.info, {super.key, this.action});
  final EmployerInfo info;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final s = statusInfo(info);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: s.color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: s.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(s.icon, color: s.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title,
                    style: text.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(s.message, style: const TextStyle(height: 1.4)),
                if (action != null) ...[const SizedBox(height: 12), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}