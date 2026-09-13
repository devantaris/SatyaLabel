import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../models/scan_models.dart';
import 'theme.dart';

Color verdictColor(Verdict verdict, ColorScheme scheme) => switch (verdict) {
      Verdict.compliant => AppColors.compliant,
      Verdict.nonCompliant => AppColors.nonCompliant,
      Verdict.needsVerification => AppColors.needsVerify,
      Verdict.unknown => scheme.outline,
    };

Color verdictBgColor(Verdict verdict) => switch (verdict) {
      Verdict.compliant => AppColors.compliantBg,
      Verdict.nonCompliant => AppColors.nonCompliantBg,
      Verdict.needsVerification => AppColors.needsVerifyBg,
      Verdict.unknown => const Color(0xFFF1F5F9),
    };

Color verdictBorderColor(Verdict verdict) => switch (verdict) {
      Verdict.compliant => AppColors.compliantBorder,
      Verdict.nonCompliant => AppColors.nonCompliantBorder,
      Verdict.needsVerification => AppColors.needsVerifyBorder,
      Verdict.unknown => AppColors.border,
    };

IconData verdictIcon(Verdict verdict) => switch (verdict) {
      Verdict.compliant => Icons.check_circle,
      Verdict.nonCompliant => Icons.cancel,
      Verdict.needsVerification => Icons.help,
      Verdict.unknown => Icons.help,
    };

String verdictLabel(Verdict verdict) => switch (verdict) {
      Verdict.compliant => 'COMPLIANT',
      Verdict.nonCompliant => 'NON-COMPLIANT',
      Verdict.needsVerification => 'NEEDS VERIFICATION',
      Verdict.unknown => 'UNKNOWN',
    };

/// National Tricolor Stripe (Saffron, White, Green)
class TricolorStripe extends StatelessWidget {
  const TricolorStripe({super.key, this.height = 3.0});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFF9933), // Indian Saffron
            Color(0xFFFFFFFF), // White
            Color(0xFF138808), // Indian Green
          ],
          stops: [0.33, 0.5, 0.67],
        ),
      ),
    );
  }
}

/// Official State Emblem & Department Watermark / Logo
class StateEmblemMark extends StatelessWidget {
  const StateEmblemMark({super.key, this.size = 28, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: (color ?? AppColors.gold).withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(
          color: (color ?? AppColors.gold).withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.balance,
          size: size * 0.58,
          color: color ?? AppColors.gold,
        ),
      ),
    );
  }
}

class VerdictBanner extends StatelessWidget {
  const VerdictBanner({super.key, required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = verdictColor(result.verdict, scheme);
    final bgColor = verdictBgColor(result.verdict);
    final borderColor = verdictBorderColor(result.verdict);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        children: [
          Icon(verdictIcon(result.verdict), color: color, size: 48),
          const SizedBox(height: 10),
          Text(
            verdictLabel(result.verdict),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          if (result.summary != null && result.summary!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              result.summary!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
          letterSpacing: 0.3,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            action!,
          ],
        ],
      ),
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
}

/// Extracts a human-friendly message from any API/network failure.
String errorMessage(Object error) => switch (error) {
      ApiException e => 'Server error (${e.statusCode}): ${e.message}',
      NetworkException e => e.message,
      _ => error.toString(),
    };

class DashboardStatCard extends StatelessWidget {
  const DashboardStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060B2545),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 17),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: AppColors.slateLight,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.3,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.slateMuted,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final String? badgeText;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040B2545),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.2), width: 0.8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.navy,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badgeText != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: (badgeColor ?? color).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: (badgeColor ?? color).withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                badgeText!,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: badgeColor ?? color,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.slateMuted,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.slateLight,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.slateMuted,
            ),
          ),
          if (actionLabel != null && onAction != null)
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
