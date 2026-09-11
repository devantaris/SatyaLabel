import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/scan_models.dart';
import '../../state/app_state.dart';
import '../scan/camera_screen.dart';
import '../scan/scan_result_screen.dart';
import '../widgets.dart';

/// Inspector raid sessions: create/join a session, scan products under it,
/// review the session's scans (verdict summary + history).
class BatchSessionsScreen extends StatelessWidget {
  const BatchSessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final sessions = app.sessionIds;

    return Scaffold(
      appBar: AppBar(title: const Text('Raid Sessions')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Session'),
        onPressed: () => _startSessionFlow(context, app),
      ),
      body: sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No raid sessions yet'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _startSessionFlow(context, app),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Start a Raid'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: sessions.length,
              itemBuilder: (context, i) => Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory),
                  title: Text(sessions[i]),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SessionDetailScreen(sessionId: sessions[i]),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _startSessionFlow(BuildContext context, AppState app) async {
    final sessionId = app.newSessionId();
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(sessionId: sessionId),
      ),
    );
    if (context.mounted) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SessionDetailScreen(sessionId: sessionId),
        ),
      );
    }
  }
}

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

enum _LoadState { loading, loaded, error }

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  _LoadState _state = _LoadState.loading;
  String _error = '';
  ScanList? _list;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final list = await context
          .read<AppState>()
          .api
          .listScans(sessionId: widget.sessionId, limit: 100);
      if (!mounted) return;
      setState(() {
        _list = list;
        _state = _LoadState.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _state = _LoadState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.sessionId)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.camera_alt),
        label: const Text('Scan Product'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CameraScreen(sessionId: widget.sessionId),
          ),
        ).then((_) => _load()),
      ),
      body: switch (_state) {
        _LoadState.loading => const Center(child: CircularProgressIndicator()),
        _LoadState.error => _ErrorView(error: _error, onRetry: _load),
        _LoadState.loaded => _SessionBody(
            list: _list!, onScanTapped: _openScan, onRefresh: _load),
      },
    );
  }

  Future<void> _openScan(ScanResult summary) async {
    try {
      final full = await context.read<AppState>().api.getScan(summary.scanId);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ScanResultScreen(result: full)),
      );
      _load();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    }
  }
}

class _SessionBody extends StatelessWidget {
  const _SessionBody({
    required this.list,
    required this.onScanTapped,
    required this.onRefresh,
  });

  final ScanList list;
  final void Function(ScanResult) onScanTapped;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final items = list.items;
    final compliant = items
        .where((s) => s.verdict == Verdict.compliant)
        .length;
    final nonCompliant = items
        .where((s) => s.verdict == Verdict.nonCompliant)
        .length;
    final needsVerification = items
        .where((s) => s.verdict == Verdict.needsVerification)
        .length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Stat('Scans', items.length.toString(), Colors.blue),
                _Stat('Compliant', compliant.toString(), Colors.green),
                _Stat('Non-Compliant', nonCompliant.toString(), Colors.red),
                _Stat('Verify', needsVerification.toString(), Colors.amber),
              ],
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No scans in this session yet.\nTap "Scan Product" to begin.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            for (final scan in items)
              Card(
                child: ListTile(
                  leading: Icon(
                    verdictIcon(scan.verdict),
                    color: verdictColor(scan.verdict, Theme.of(context).colorScheme),
                  ),
                  title: Text(
                    scan.verdict == Verdict.unknown
                        ? scan.status
                        : verdictLabel(scan.verdict),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${scan.scanId.substring(0, 8)} · ${scan.createdAt ?? ''}'
                    '${scan.violations.isNotEmpty ? ' · ${scan.violations.length} finding(s)' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onScanTapped(scan),
                ),
              ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
