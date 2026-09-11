import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../models/scan_models.dart';

Color verdictColor(Verdict verdict, ColorScheme scheme) => switch (verdict) {
      Verdict.compliant => Colors.green.shade700,
      Verdict.nonCompliant => Colors.red.shade700,
      Verdict.needsVerification => Colors.amber.shade800,
      Verdict.unknown => scheme.outline,
    };

IconData verdictIcon(Verdict verdict) => switch (verdict) {
      Verdict.compliant => Icons.check_circle,
      Verdict.nonCompliant => Icons.cancel,
      Verdict.needsVerification => Icons.help,
      Verdict.unknown => Icons.question_mark,
    };

String verdictLabel(Verdict verdict) => switch (verdict) {
      Verdict.compliant => 'COMPLIANT',
      Verdict.nonCompliant => 'NON-COMPLIANT',
      Verdict.needsVerification => 'NEEDS VERIFICATION',
      Verdict.unknown => 'UNKNOWN',
    };

class VerdictBanner extends StatelessWidget {
  const VerdictBanner({super.key, required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = verdictColor(result.verdict, scheme);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12)),
      child: Column(
        children: [
          Icon(verdictIcon(result.verdict), color: color, size: 56),
          const SizedBox(height: 8),
          Text(
            verdictLabel(result.verdict),
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
          if (result.summary != null) ...[
            const SizedBox(height: 8),
            Text(
              result.summary!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class SeverityChip extends StatelessWidget {
  const SeverityChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.icon,
    required this.message,
    required this.color,
    this.action,
  });

  final IconData icon;
  final String message;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: TextStyle(color: color))),
            if (action != null) action!,
          ],
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Extracts a human-friendly message from any API/network failure.
String errorMessage(Object error) => switch (error) {
      ApiException e => 'Server error (${e.statusCode}): ${e.message}',
      NetworkException e => e.message,
      _ => error.toString(),
    };
