import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../state/app_state.dart';
import '../widgets.dart';

/// Inspector/admin analytics dashboard: overview stats, violation hotspots
/// (PostGIS heatmap), repeat-offender manufacturers, district stats, and
/// CSV evidence export for legal action.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

enum _LoadState { loading, loaded, error }

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _LoadState _state = _LoadState.loading;
  String _error = '';
  int _daysFilter = 0; // 0 = all time

  Map<String, dynamic> _overview = {};
  List<dynamic> _heatPoints = [];
  List<dynamic> _manufacturers = [];
  List<dynamic> _districts = [];

  bool _exporting = false;

  int? get _days => _daysFilter == 0 ? null : _daysFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final api = context.read<AppState>().api;
      final results = await Future.wait([
        api.analyticsOverview(days: _days),
        api.analyticsHeatmap(days: _days),
        api.analyticsManufacturers(days: _days),
        api.analyticsDistricts(days: _days),
      ]);
      if (!mounted) return;
      setState(() {
        _overview = results[0];
        _heatPoints = (results[1])['points'] as List;
        _manufacturers = (results[2])['items'] as List;
        _districts = (results[3])['items'] as List;
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

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final csv = await context.read<AppState>().api.analyticsExportCsv(
            days: _days,
          );
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/satyalabel_evidence_'
        '${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(csv, flush: true);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'SatyaLabel evidence export',
      );
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analytics'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _state == _LoadState.loading ? null : _load,
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Hotspots'),
              Tab(text: 'Offenders'),
            ],
          ),
        ),
        body: Column(
          children: [
            _daysSelector(),
            Expanded(
              child: switch (_state) {
                _LoadState.loading => const Center(
                    child: CircularProgressIndicator()),
                _LoadState.error => _ErrorView(
                    error: _error,
                    onRetry: _load,
                  ),
                _LoadState.loaded => TabBarView(
                    children: [
                      _overviewTab(),
                      _hotspotsTab(),
                      _offendersTab(),
                    ],
                  ),
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: _exporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_download),
          label: const Text('Export CSV'),
          onPressed: _exporting ? null : _exportCsv,
        ),
      ),
    );
  }

  Widget _daysSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Window:'),
          const SizedBox(width: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final days in const [0, 7, 30])
                ChoiceChip(
                  label: Text(days == 0 ? 'All' : '$days d'),
                  selected: _daysFilter == days,
                  onSelected: (_) {
                    setState(() => _daysFilter = days);
                    _load();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewTab() {
    final stats = [
      ('Total scans', _overview['total_scans'], Colors.blue),
      ('Non-compliant', _overview['non_compliant'], Colors.red),
      ('Needs verify', _overview['needs_verification'], Colors.amber),
      ('Compliant', _overview['compliant'], Colors.green),
      ('Needs review', _overview['needs_review'], Colors.orange),
      ('Raid sessions', _overview['sessions'], Colors.indigo),
      ('Last 24 h', _overview['scans_24h'], Colors.teal),
    ];
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (label, value, color) in stats)
                SizedBox(
                  width: 105,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            '${value ?? 0}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _SectionCard(
          title: 'District Statistics',
          child: _districts.isEmpty
              ? const _EmptyHint(
                  text: 'No district data yet — scans made by registered '
                      'inspectors appear here.')
              : Column(
                  children: [
                    for (final d in _districts)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_city),
                        title: Text('${d['district']}'),
                        subtitle: Text(
                          '${d['total_scans']} scans · '
                          '${d['non_compliant']} non-compliant · '
                          '${d['contributors']} contributor(s)',
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _hotspotsTab() {
    return ListView(
      children: [
        _SectionCard(
          title: 'Violation Hotspots (${_heatPoints.length})',
          subtitle: 'Geo-tagged scans binned to a ~5 km grid, worst first',
          child: _heatPoints.isEmpty
              ? const _EmptyHint(
                  text: 'No geo-tagged scans yet. Scans with GPS enabled '
                      'appear on the heatmap.')
              : Column(
                  children: [
                    for (final p in _heatPoints)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.local_fire_department,
                          color: (p['violations'] as int? ?? 0) > 0
                              ? Colors.red
                              : Colors.amber,
                        ),
                        title: Text(
                          '${p['latitude']}, ${p['longitude']}',
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 13),
                        ),
                        subtitle: Text(
                          '${p['total_scans']} scans · '
                          '${p['violations']} violations · '
                          '${((p['violation_rate'] as num? ?? 0) * 100).round()}% rate',
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _offendersTab() {
    return ListView(
      children: [
        _SectionCard(
          title: 'Repeat Offenders (${_manufacturers.length})',
          subtitle: 'Manufacturers ranked by non-compliant scans '
              '(legal follow-up list)',
          child: _manufacturers.isEmpty
              ? const _EmptyHint(
                  text: 'No manufacturer data yet — at least two scans of '
                      'the same manufacturer are needed.')
              : Column(
                  children: [
                    for (final m in _manufacturers)
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor:
                              (m['non_compliant'] as int? ?? 0) > 0
                                  ? Colors.red.withValues(alpha: 0.15)
                                  : Colors.grey.withValues(alpha: 0.15),
                          child: Text(
                            (m['manufacturer'] as String?)?[0] ?? '?',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text('${m['manufacturer']}'),
                        subtitle: Text(
                          '${m['non_compliant']} non-compliant · '
                          '${m['needs_verification']} verify · '
                          '${m['compliant']} compliant '
                          '(${m['total_scans']} total)',
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
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
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
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
