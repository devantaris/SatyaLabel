import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/scan_models.dart';
import '../../state/app_state.dart';
import '../widgets.dart';

/// Verdict display: violations with rule citations, extracted fields,
/// OCR diagnostics, PDF evidence-report download.
class ScanResultScreen extends StatefulWidget {
  const ScanResultScreen({
    super.key,
    required this.result,
    this.imageBytes,
    this.batchMode = false,
    this.refreshable = false,
  });

  final ScanResult result;
  final Uint8List? imageBytes;
  final bool batchMode;

  /// When true, offers a refresh action (used for PENDING async scans).
  final bool refreshable;

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  late ScanResult result;
  bool _pdfLoading = false;
  String? _pdfError;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    result = widget.result;
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final fresh = await context.read<AppState>().api.getScan(result.scanId);
      if (mounted) setState(() => result = fresh);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _downloadReport() async {
    final app = context.read<AppState>();
    if (widget.imageBytes == null) {
      setState(() => _pdfError = 'Original image not available for this scan.');
      return;
    }
    setState(() {
      _pdfLoading = true;
      _pdfError = null;
    });
    try {
      final user = app.user;
      final pdf = await app.api.requestPdfReport(
        widget.imageBytes!,
        mimeType: 'image/jpeg',
        inspectorBadge: user?.badgeNumber,
        inspectorName: user?.displayName,
        locationHint: result.location == null
            ? null
            : '${result.location!.latitude}, ${result.location!.longitude}',
        ocrText: result.ocrRawText,
      );
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/SatyaLabel_Evidence_${result.scanId.substring(0, 8)}.pdf',
      );
      await file.writeAsBytes(pdf, flush: true);
      if (!mounted) return;
      setState(() => _pdfLoading = false);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'SatyaLabel evidence report',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pdfLoading = false;
        _pdfError = errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Result'),
        actions: [
          if (widget.refreshable)
            IconButton(
              onPressed: _refreshing ? null : _refresh,
              icon: _refreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          VerdictBanner(result: result),
          if (result.needsReview)
            const StatusBanner(
              icon: Icons.visibility,
              message: 'Low OCR confidence — manual verification recommended',
              color: Colors.amber,
            ),
          if (result.status == 'PENDING' || result.status == 'PROCESSING')
            const StatusBanner(
              icon: Icons.hourglass_top,
              message: 'Scan is still being processed — refresh for the verdict',
              color: Colors.blue,
            ),
          if (result.status == 'FAILED')
            const StatusBanner(
              icon: Icons.error,
              message: 'Processing failed on the server',
              color: Colors.red,
            ),
          const SizedBox(height: 8),
          _Section(
            title: 'Violations (${result.criticalCount} critical, '
                '${result.warningCount} warnings)',
            child: result.violations.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No violations found — label satisfies all '
                        'checked LM(PC) Rules, 2011 declarations.'),
                  )
                : Column(
                    children: [
                      for (final v in result.violations) _ViolationTile(violation: v),
                    ],
                  ),
          ),
          _Section(
            title: 'Extracted Declarations',
            child: result.extractedFields.isEmpty
                ? const Text('No fields extracted.')
                : Column(
                    children: [
                      for (final f in result.extractedFields)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            f.found ? Icons.check : Icons.close,
                            color: f.found ? Colors.green : Colors.red,
                          ),
                          title: Text(f.name.replaceAll('_', ' ')),
                          subtitle: Text(
                            f.found
                                ? '${f.value ?? ''}'
                                  '${f.confidence != null ? ' (conf ${(f.confidence! * 100).round()}%)' : ''}'
                                : 'not found on label',
                          ),
                        ),
                    ],
                  ),
          ),
          _Section(
            title: 'OCR & Diagnostics',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('Scan ID', result.scanId),
                _kv('Status', result.status),
                _kv('OCR engine', result.ocrEngine ?? '—'),
                _kv('OCR confidence', result.ocrConfidence == null
                    ? '—'
                    : '${(result.ocrConfidence! * 100).round()}%'),
                if (result.sessionId != null) _kv('Session', result.sessionId!),
                if (result.location != null)
                  _kv('Location',
                      '${result.location!.latitude}, ${result.location!.longitude}'),
                _kv('Scanned at', result.createdAt ?? '—'),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_pdfError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_pdfError!,
                      style: TextStyle(color: scheme.error), textAlign: TextAlign.center),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pdfLoading ? null : _downloadReport,
                      icon: _pdfLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf),
                      label: Text(_pdfLoading ? 'Generating…' : 'PDF Evidence Report'),
                    ),
                  ),
                  if (widget.batchMode) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context, 'scan-next'),
                        icon: const Icon(Icons.camera),
                        label: const Text('Scan Next'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(key, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _ViolationTile extends StatelessWidget {
  const _ViolationTile({required this.violation});

  final Violation violation;

  @override
  Widget build(BuildContext context) {
    final critical = violation.isCritical;
    final color = critical ? Colors.red.shade700 : Colors.amber.shade800;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(critical ? Icons.gavel : Icons.warning_amber,
              color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SeverityChip(
                      label: critical ? 'CRITICAL' : 'WARNING',
                      color: color,
                    ),
                    Text(
                      violation.field.replaceAll('_', ' '),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(violation.message),
                if (violation.rule != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    violation.rule!,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
