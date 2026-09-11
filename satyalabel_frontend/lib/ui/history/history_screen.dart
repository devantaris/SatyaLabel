import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/scan_models.dart';
import '../../state/app_state.dart';
import '../scan/scan_result_screen.dart';
import '../widgets.dart';

/// Local scan history: scans made on this device (citizen and inspector).
/// Each entry is fetched by id with its own loading/error state.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<String>? _ids;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ids = context.read<AppState>().localScanIds;
  }

  @override
  Widget build(BuildContext context) {
    final ids = _ids ?? const <String>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Scan History')),
      body: ids.isEmpty
          ? const Center(
              child: Text('No scans yet.\nScan a label to get started.',
                  textAlign: TextAlign.center),
            )
          : ListView.builder(
              itemCount: ids.length,
              itemBuilder: (context, i) => _HistoryTile(scanId: ids[i]),
            ),
    );
  }
}

class _HistoryTile extends StatefulWidget {
  const _HistoryTile({required this.scanId});

  final String scanId;

  @override
  State<_HistoryTile> createState() => _HistoryTileState();
}

enum _TileState { loading, loaded, error }

class _HistoryTileState extends State<_HistoryTile> {
  _TileState _state = _TileState.loading;
  ScanResult? _result;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _TileState.loading);
    try {
      final result = await context.read<AppState>().api.getScan(widget.scanId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _state = _TileState.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _state = _TileState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: switch (_state) {
        _TileState.loading => const ListTile(
            leading: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text('Loading…'),
          ),
        _TileState.error => ListTile(
            leading: Icon(Icons.error_outline, color: scheme.error),
            title: const Text('Could not load scan'),
            subtitle: Text(_error, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ),
        _TileState.loaded => ListTile(
            leading: Icon(
              verdictIcon(_result!.verdict),
              color: verdictColor(_result!.verdict, scheme),
            ),
            title: Text(
              _result!.verdict == Verdict.unknown
                  ? _result!.status
                  : verdictLabel(_result!.verdict),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${_result!.scanId.substring(0, 8)} · ${_result!.createdAt ?? ''}'
              '${_result!.sessionId != null ? ' · ${_result!.sessionId}' : ''}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ScanResultScreen(
                  result: _result!,
                  refreshable: true,
                ),
              ),
            ),
          ),
      },
    );
  }
}
