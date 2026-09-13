import 'package:flutter/material.dart';
import '../scan/camera_screen.dart';

class InspectionChecklistItem {
  InspectionChecklistItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.ruleCitation,
    this.isChecked = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String ruleCitation;
  bool isChecked;
}

class ChecklistSheet extends StatefulWidget {
  const ChecklistSheet({super.key});

  @override
  State<ChecklistSheet> createState() => _ChecklistSheetState();
}

class _ChecklistSheetState extends State<ChecklistSheet> {
  final List<InspectionChecklistItem> _items = [
    InspectionChecklistItem(
      id: 'label_integrity',
      title: 'Label Integrity & Placement',
      subtitle:
          'Physical label is securely affixed, visible, and not covered by retail discount stickers.',
      ruleCitation: 'Rule 4 & 6(1)',
    ),
    InspectionChecklistItem(
      id: 'mrp_legibility',
      title: 'MRP & Dual-Pricing Check',
      subtitle:
          'MRP is clearly printed with "incl. of all taxes". No scratched-out prices or secondary higher stickers.',
      ruleCitation: 'Rule 6(1)(e)',
    ),
    InspectionChecklistItem(
      id: 'unit_sale_price',
      title: 'Unit Sale Price (USP) Displayed',
      subtitle:
          'Mandatory for packages > 1 kg or 1 L. Displayed as ₹ per g, ₹ per kg, ₹ per ml, or ₹ per piece.',
      ruleCitation: 'Rule 6(1)(da)',
    ),
    InspectionChecklistItem(
      id: 'manufacturer_address',
      title: 'Complete Manufacturer / Packer Identity',
      subtitle:
          'Full physical premises address including city, state, and 6-digit postal PIN code.',
      ruleCitation: 'Rule 6(1)(a)',
    ),
    InspectionChecklistItem(
      id: 'date_declaration',
      title: 'Month & Year of Manufacture / Import',
      subtitle:
          'Clearly printed in MM/YYYY or words. Inkjet date is legible and not smudged.',
      ruleCitation: 'Rule 6(1)(d)',
    ),
    InspectionChecklistItem(
      id: 'net_quantity',
      title: 'Standard Net Quantity & Units',
      subtitle:
          'Stated in approved SI units (g, kg, ml, l). No non-standard symbols like "gms" or "liters".',
      ruleCitation: 'Rule 6(1)(c)',
    ),
    InspectionChecklistItem(
      id: 'consumer_care',
      title: 'Customer Care Helpline & Email',
      subtitle:
          'Valid grievance redressal contact including working telephone number, email, and designated officer.',
      ruleCitation: 'Rule 6(1)(h)',
    ),
    InspectionChecklistItem(
      id: 'country_of_origin',
      title: 'Country of Origin (COO)',
      subtitle:
          'Mandatory declaration for all imported commodities stating country of manufacture.',
      ruleCitation: 'Rule 6(10)',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final checkedCount = _items.where((item) => item.isChecked).length;
    final totalCount = _items.length;
    final progress = totalCount == 0 ? 0.0 : checkedCount / totalCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Inspection Checklist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset Checklist',
            onPressed: () {
              setState(() {
                for (final item in _items) {
                  item.isChecked = false;
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(color: scheme.outlineVariant),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Verification Progress',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      '$checkedCount of $totalCount items verified',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: checkedCount == totalCount
                            ? Colors.green
                            : scheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: checkedCount == totalCount
                        ? Colors.green
                        : scheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  checkedCount == totalCount
                      ? 'All manual checks verified! Proceed with AI OCR scan to record evidence.'
                      : 'Verify physical packaging markers before completing AI compliance scan.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final item = _items[i];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: CheckboxListTile(
                    value: item.isChecked,
                    onChanged: (val) {
                      setState(() => item.isChecked = val ?? false);
                    },
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration: item.isChecked
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(item.subtitle),
                        const SizedBox(height: 4),
                        Text(
                          item.ruleCitation,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CameraScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('Start AI Scan for this Package'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
