import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../history/history_screen.dart';

class GrievanceSheet extends StatelessWidget {
  const GrievanceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grievance & Violation Reporting'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: scheme.primaryContainer.withValues(alpha: 0.6),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.shield, size: 40, color: scheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Legal Metrology Protection',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: scheme.onPrimaryContainer,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Consumers have the statutory right under the Legal Metrology Act, 2009 and Consumer Protection Act, 2019 to non-deceptive packaging, accurate MRP, and transparent quantities.',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Official Reporting Channels',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          _ChannelCard(
            icon: Icons.phone_in_talk,
            title: 'National Consumer Helpline (NCH)',
            subtitle: 'Toll-free 1915 or SMS/WhatsApp to 8800001915',
            description:
                'Government of India portal for immediate grievance logging against overcharging above MRP or missing statutory declarations.',
            actionLabel: 'Copy 1915',
            onAction: () {
              Clipboard.setData(const ClipboardData(text: '1915'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Helpline number 1915 copied to clipboard')),
              );
            },
          ),
          _ChannelCard(
            icon: Icons.language,
            title: 'INGRAM Portal (consumerhelpline.gov.in)',
            subtitle: 'Integrated Grievance Redress Mechanism',
            description:
                'Register complaints online, attach SatyaLabel PDF evidence reports, and track status with a unique docket number.',
            actionLabel: 'Copy URL',
            onAction: () {
              Clipboard.setData(
                  const ClipboardData(text: 'https://consumerhelpline.gov.in'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('INGRAM URL copied to clipboard')),
              );
            },
          ),
          _ChannelCard(
            icon: Icons.balance,
            title: 'e-Daakhil (edaakhil.nic.in)',
            subtitle: 'National Consumer Dispute Redressal Commission',
            description:
                'File formal consumer court cases online for unfair trade practices, dual pricing, and deceptive labeling.',
            actionLabel: 'Copy Portal',
            onAction: () {
              Clipboard.setData(const ClipboardData(text: 'https://edaakhil.nic.in'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('e-Daakhil URL copied to clipboard')),
              );
            },
          ),
          _ChannelCard(
            icon: Icons.location_city,
            title: 'State Legal Metrology Controller',
            subtitle: 'Department of Food, Civil Supplies & Consumer Affairs',
            description:
                'District Legal Metrology inspectors conduct market raids and compound offences under Section 48 of the Act.',
            actionLabel: null,
            onAction: null,
          ),
          const SizedBox(height: 16),
          Text(
            'How to Prepare Evidence with SatyaLabel',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StepRow(
                    step: '1',
                    text: 'Scan the suspect package label using the SatyaLabel camera.',
                  ),
                  const SizedBox(height: 12),
                  _StepRow(
                    step: '2',
                    text:
                        'Review detected violations (missing USP, altered MRP, invalid font).',
                  ),
                  const SizedBox(height: 12),
                  _StepRow(
                    step: '3',
                    text:
                        'Tap "Download Evidence Report" to generate a tamper-evident PDF with GPS stamp.',
                  ),
                  const SizedBox(height: 12),
                  _StepRow(
                    step: '4',
                    text:
                        'Attach the PDF to your complaint on NCH 1915 or e-Daakhil.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HistoryScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history),
                    label: const Text('Open Scan History for Evidence'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.secondaryContainer,
                  foregroundColor: scheme.onSecondaryContainer,
                  child: Icon(icon, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  TextButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.text});

  final String step;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          child: Text(step, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}
