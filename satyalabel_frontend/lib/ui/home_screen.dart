import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/scan_models.dart';
import '../state/app_state.dart';
import 'analytics/analytics_screen.dart';
import 'auth/login_screen.dart';
import 'batch/batch_sessions_screen.dart';
import 'checklist/checklist_sheet.dart';
import 'diagnostics/diagnostics_sheet.dart';
import 'grievance/grievance_sheet.dart';
import 'history/history_screen.dart';
import 'queue/queue_sheet.dart';
import 'rules/rules_sheet.dart';
import 'scan/camera_screen.dart';
import 'scan/scan_result_screen.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().refreshConnectivity();
    });
  }

  void _navigateToTab(int index) {
    setState(() => _selectedTabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.verified, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SatyaLabel',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'Legal Metrology Compliance',
                  style: TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          _ConnectivityBadge(
            app: app,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QueueSheet()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Backend Connection',
            onPressed: () => _editBaseUrl(context, app),
          ),
          IconButton(
            icon: Icon(app.isLoggedIn ? Icons.account_circle : Icons.login),
            tooltip: app.isLoggedIn ? 'Account Profile' : 'Log in',
            onPressed: () => _onAuthPressed(context, app),
          ),
        ],
      ),
      drawer: _AppDrawer(
        app: app,
        onNavigateTab: _navigateToTab,
        onEditBaseUrl: () => _editBaseUrl(context, app),
        onAuthPressed: () => _onAuthPressed(context, app),
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          _DashboardTabView(
            onNavigateTab: _navigateToTab,
            onEditBaseUrl: () => _editBaseUrl(context, app),
          ),
          const HistoryScreen(),
          const BatchSessionsScreen(),
          const RulesSheet(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (i) => setState(() => _selectedTabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Records',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Raids',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Standards',
          ),
        ],
      ),
      floatingActionButton: _selectedTabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CameraScreen()),
              ),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Label'),
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            )
          : null,
    );
  }

  Future<void> _onAuthPressed(BuildContext context, AppState app) async {
    if (app.isLoggedIn) {
      final user = app.user;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                app.isInspector ? Icons.shield : Icons.person,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Active Session'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Signed in as ${user?.displayName ?? user?.email}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Role: ${user?.role.toUpperCase() ?? 'CITIZEN'}',
                style: TextStyle(
                  color: app.isInspector ? Colors.teal.shade800 : Colors.blueGrey,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (user?.badgeNumber != null) ...[
                const SizedBox(height: 4),
                Text('Badge ID: ${user!.badgeNumber}'),
              ],
              if (user?.district != null) ...[
                const SizedBox(height: 4),
                Text('District: ${user!.district}'),
              ],
              const Divider(height: 24),
              const Text('Would you like to log out of this device?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Log Out'),
            ),
          ],
        ),
      );
      if (confirmed == true) await app.logout();
    } else {
      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  Future<void> _editBaseUrl(BuildContext context, AppState app) async {
    final controller = TextEditingController(text: app.api.baseUrl);
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.dns),
            SizedBox(width: 8),
            Text('Backend URL'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'http://10.0.2.2:8000',
                labelText: 'Base URL',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '• 10.0.2.2: Android Emulator\n'
              '• 127.0.0.1: ADB reverse tunnel\n'
              '• LAN IP: Physical WiFi device\n'
              'Restart the app after changing to apply.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (url != null && url.isNotEmpty && url != app.api.baseUrl) {
      await app.setBaseUrl(url);
      if (context.mounted) {
        showSnack(context, 'Backend URL saved — restart the app to apply');
      }
    }
  }
}

class _ConnectivityBadge extends StatelessWidget {
  const _ConnectivityBadge({required this.app, required this.onTap});

  final AppState app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isOffline = !app.backendReachable || !app.hasNetwork;
    final int queueCount = app.queue.length;

    Color badgeColor;
    IconData icon;
    String label;

    if (queueCount > 0) {
      badgeColor = Colors.amber.shade300;
      icon = Icons.cloud_upload;
      label = '$queueCount';
    } else if (isOffline) {
      badgeColor = Colors.orangeAccent;
      icon = Icons.cloud_off;
      label = 'Offline';
    } else {
      badgeColor = Colors.lightGreenAccent;
      icon = Icons.check_circle;
      label = 'Live';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: badgeColor.withValues(alpha: 0.6), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: badgeColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: badgeColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTabView extends StatelessWidget {
  const _DashboardTabView({
    required this.onNavigateTab,
    required this.onEditBaseUrl,
  });

  final void Function(int) onNavigateTab;
  final VoidCallback onEditBaseUrl;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: app.refreshConnectivity,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (!app.backendReachable)
            StatusBanner(
              icon: Icons.cloud_off,
              message: app.hasNetwork
                  ? 'Backend unreachable at ${app.api.baseUrl} — scans are queued on disk'
                  : 'No network connection — offline evidence queue active',
              color: Colors.orange,
              action: TextButton(
                onPressed: onEditBaseUrl,
                child: const Text('Change URL'),
              ),
            ),
          if (app.queue.isNotEmpty)
            StatusBanner(
              icon: app.queue.syncing ? Icons.sync : Icons.queue,
              message: app.queue.syncing
                  ? 'Syncing ${app.queue.length} queued scan(s)...'
                  : '${app.queue.length} scan(s) waiting in offline queue',
              color: scheme.primary,
              action: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QueueSheet()),
                  );
                },
                child: const Text('View Queue'),
              ),
            ),

          // Hero Welcome Card
          _HeroWelcomeCard(app: app),

          // Stat counters strip
          _StatsGrid(app: app, onNavigateTab: onNavigateTab),

          // Primary Scan Action Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Card(
              color: scheme.primary,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CameraScreen()),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Compliance Scan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Capture packaged commodity label to verify Rule 6 declarations, MRP, USP & font sizes instantly.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Inspection & Enforcement Center
          SectionHeader(
            title: 'ENFORCEMENT & COMPLIANCE TOOLS',
            actionLabel: 'Checklist',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChecklistSheet()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                QuickActionTile(
                  icon: Icons.inventory_2,
                  color: Colors.indigo,
                  title: 'Batch Raid Sessions',
                  subtitle:
                      'Group multiple market package scans under one raid session ID with consolidated evidence.',
                  badgeText: app.isInspector ? 'OFFICER' : null,
                  badgeColor: Colors.indigo,
                  onTap: () => onNavigateTab(2),
                ),
                const SizedBox(height: 8),
                QuickActionTile(
                  icon: Icons.insights,
                  color: Colors.deepOrange,
                  title: 'Analytics & Violation Hotspots',
                  subtitle:
                      'District violation heatmaps, repeat offender rankings, and CSV evidentiary export.',
                  badgeText: 'HEATMAP',
                  badgeColor: Colors.deepOrange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                  ),
                ),
                const SizedBox(height: 8),
                QuickActionTile(
                  icon: Icons.checklist_rtl,
                  color: Colors.teal,
                  title: 'Field Verification Checklist',
                  subtitle:
                      'Physical package integrity checklist: dual pricing, PIN code completeness, font size, and COO.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChecklistSheet()),
                  ),
                ),
                const SizedBox(height: 8),
                QuickActionTile(
                  icon: Icons.menu_book,
                  color: Colors.blueGrey,
                  title: 'LM(PC) Rules 2011 Standards',
                  subtitle:
                      'Full statutory reference for Rule 6(1) declarations, Table 1 font heights, and Section 36 penalties.',
                  onTap: () => onNavigateTab(3),
                ),
              ],
            ),
          ),

          // Consumer Protection & Redressal
          SectionHeader(
            title: 'CONSUMER GRIEVANCES & SYNC',
            actionLabel: 'Helpline 1915',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GrievanceSheet()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: QuickActionTile(
                    icon: Icons.support_agent,
                    color: Colors.purple,
                    title: 'NCH 1915',
                    subtitle: 'Grievance escalation portal & e-Daakhil',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GrievanceSheet()),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: QuickActionTile(
                    icon: Icons.sync,
                    color: Colors.blue,
                    title: 'Offline Sync',
                    subtitle: '${app.queue.length} pending scans on disk',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QueueSheet()),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Recent Scans Feed
          SectionHeader(
            title: 'RECENT INSPECTION ACTIVITY',
            actionLabel: 'View All (${app.localScanIds.length})',
            onAction: () => onNavigateTab(1),
          ),
          _RecentScansSection(app: app),

          // Statutory Note of the Day
          const _ComplianceAdvisoryCard(),

          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text(
                  'Legal Metrology (Packaged Commodities) Rules, 2011',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'SIH 2026 · Ministry of Consumer Affairs, Food & Public Distribution',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroWelcomeCard extends StatelessWidget {
  const _HeroWelcomeCard({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isInspector = app.isInspector;
    final user = app.user;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isInspector
                ? Colors.red.withValues(alpha: 0.12)
                : scheme.primary.withValues(alpha: 0.12),
            child: Icon(
              isInspector ? Icons.verified_user : Icons.person,
              color: isInspector ? Colors.red.shade700 : scheme.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isInspector ? 'OFFICIAL INSPECTOR' : 'CITIZEN SCANNER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: isInspector ? Colors.red.shade700 : scheme.primary,
                      ),
                    ),
                    if (user?.badgeNumber != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          user!.badgeNumber!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  app.isLoggedIn
                      ? 'Namaste, ${user?.displayName ?? 'Officer'}'
                      : 'Welcome to SatyaLabel',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  user?.district != null
                      ? 'Jurisdiction: ${user!.district}'
                      : 'Scan & verify pre-packaged consumer goods',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.app, required this.onNavigateTab});

  final AppState app;
  final void Function(int) onNavigateTab;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.7,
        children: [
          DashboardStatCard(
            title: 'Scans Recorded',
            value: '${app.localScanIds.length}',
            icon: Icons.history,
            color: Colors.teal.shade700,
            subtitle: 'On this device',
            onTap: () => onNavigateTab(1),
          ),
          DashboardStatCard(
            title: 'Offline Queue',
            value: '${app.queue.length}',
            icon: Icons.cloud_queue,
            color: app.queue.isNotEmpty ? Colors.orange.shade800 : Colors.blueGrey,
            subtitle: app.queue.isNotEmpty ? 'Pending sync' : 'All synced',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QueueSheet()),
            ),
          ),
          DashboardStatCard(
            title: 'Raid Batches',
            value: '${app.sessionIds.length}',
            icon: Icons.inventory_2,
            color: Colors.indigo.shade700,
            subtitle: 'Inspector sessions',
            onTap: () => onNavigateTab(2),
          ),
          DashboardStatCard(
            title: 'Engine Health',
            value: app.backendReachable ? 'Online' : 'Offline',
            icon: app.backendReachable ? Icons.dns : Icons.cloud_off,
            color: app.backendReachable ? Colors.green.shade700 : Colors.red.shade700,
            subtitle: 'Tap for diagnostics',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DiagnosticsSheet()),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentScansSection extends StatelessWidget {
  const _RecentScansSection({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final recentIds = app.localScanIds.reversed.take(3).toList();

    if (recentIds.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.document_scanner, size: 40, color: Colors.grey),
              const SizedBox(height: 8),
              const Text(
                'No scans recorded yet',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap "AI Compliance Scan" above to scan your first product label.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final id in recentIds) _RecentScanTile(scanId: id),
        ],
      ),
    );
  }
}

class _RecentScanTile extends StatefulWidget {
  const _RecentScanTile({required this.scanId});

  final String scanId;

  @override
  State<_RecentScanTile> createState() => _RecentScanTileState();
}

class _RecentScanTileState extends State<_RecentScanTile> {
  ScanResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await context.read<AppState>().api.getScan(widget.scanId);
      if (mounted) {
        setState(() {
          _result = res;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Card(
        margin: EdgeInsets.only(bottom: 8),
        child: ListTile(
          dense: true,
          leading: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('Loading scan...'),
        ),
      );
    }

    final res = _result;
    if (res == null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.help_outline, color: Colors.grey),
          title: Text('Scan #${widget.scanId.substring(0, 8)}'),
          subtitle: const Text('Cached offline or pending sync'),
        ),
      );
    }

    final color = verdictColor(res.verdict, scheme);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(verdictIcon(res.verdict), color: color, size: 24),
        title: Row(
          children: [
            Text(
              res.verdict == Verdict.unknown ? res.status : verdictLabel(res.verdict),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '#${res.scanId.substring(0, 6)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        subtitle: Text(
          res.summary ??
              (res.violations.isNotEmpty
                  ? '${res.violations.length} violation finding(s)'
                  : 'All mandatory declarations verified'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ScanResultScreen(result: res, refreshable: true),
            ),
          );
        },
      ),
    );
  }
}

class _ComplianceAdvisoryCard extends StatelessWidget {
  const _ComplianceAdvisoryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.amber.shade900, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Regulatory Note: Unit Sale Price (USP)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Under Rule 6(1)(da) of LM(PC) Rules 2011, commodities sold by weight or measure must declare the Unit Sale Price (e.g. ₹ per g or ₹ per ml) alongside the total MRP.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.brown.shade900,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.app,
    required this.onNavigateTab,
    required this.onEditBaseUrl,
    required this.onAuthPressed,
  });

  final AppState app;
  final void Function(int) onNavigateTab;
  final VoidCallback onEditBaseUrl;
  final VoidCallback onAuthPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = app.user;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: scheme.primary),
            accountName: Text(
              app.isLoggedIn
                  ? (user?.displayName ?? 'Inspector')
                  : 'SatyaLabel Citizen',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(
              app.isLoggedIn
                  ? (user?.email ?? '')
                  : 'Legal Metrology Compliance Scanner',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                app.isInspector ? Icons.shield : Icons.person,
                color: scheme.primary,
                size: 36,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context);
              onNavigateTab(0);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('AI Label Scanner'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CameraScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Scan Records & Evidence'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${app.localScanIds.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              onNavigateTab(1);
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2),
            title: const Text('Batch Raid Sessions'),
            onTap: () {
              Navigator.pop(context);
              onNavigateTab(2);
            },
          ),
          ListTile(
            leading: const Icon(Icons.insights),
            title: const Text('Analytics & Heatmaps'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.checklist_rtl),
            title: const Text('Field Inspection Checklist'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChecklistSheet()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('LM(PC) Rules 2011 Standards'),
            onTap: () {
              Navigator.pop(context);
              onNavigateTab(3);
            },
          ),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Consumer Grievance (NCH 1915)'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GrievanceSheet()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync),
            title: const Text('Offline Queue & Sync'),
            trailing: app.queue.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${app.queue.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )
                : null,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QueueSheet()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.build),
            title: const Text('System Diagnostics'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiagnosticsSheet()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.dns),
            title: const Text('Server Connection URL'),
            subtitle: Text(
              app.api.baseUrl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
            onTap: () {
              Navigator.pop(context);
              onEditBaseUrl();
            },
          ),
          ListTile(
            leading: Icon(app.isLoggedIn ? Icons.logout : Icons.login),
            title: Text(app.isLoggedIn ? 'Log Out' : 'Inspector Login'),
            onTap: () {
              Navigator.pop(context);
              onAuthPressed();
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About SatyaLabel'),
            onTap: () {
              Navigator.pop(context);
              showAboutDialog(
                context: context,
                applicationName: 'SatyaLabel',
                applicationVersion: '1.0.0 (SIH 2026)',
                applicationLegalese:
                    '© 2026 SatyaLabel Project\nLegal Metrology (Packaged Commodities) Rules, 2011 Compliance System',
                children: const [
                  SizedBox(height: 12),
                  Text(
                    'SatyaLabel equips legal metrology inspectors and citizens with explainable OCR compliance scanning, violation rule citations, offline disk queuing, and evidentiary reporting.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
