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
import 'theme.dart';
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

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Column(
          children: [
            const TricolorStripe(height: 3.5),
            AppBar(
              elevation: 0,
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              titleSpacing: 0,
              title: Row(
                children: [
                  const StateEmblemMark(size: 32, color: Color(0xFFD4AF37)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'SatyaLabel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        'DEPT. OF CONSUMER AFFAIRS · GOVT. OF INDIA',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.75),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                _ConnectivityPill(
                  app: app,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QueueSheet()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.tune_outlined, size: 20),
                  tooltip: 'Endpoint Config',
                  onPressed: () => _editBaseUrl(context, app),
                ),
                IconButton(
                  icon: Icon(
                    app.isLoggedIn ? Icons.account_circle : Icons.login,
                    size: 22,
                  ),
                  tooltip: app.isLoggedIn ? 'Officer Session' : 'Inspector Login',
                  onPressed: () => _onAuthPressed(context, app),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ],
        ),
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
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Command',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Records',
          ),
          NavigationDestination(
            icon: Icon(Icons.badge_outlined),
            selectedIcon: Icon(Icons.badge),
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
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              elevation: 3,
              icon: const Icon(Icons.document_scanner, size: 19),
              label: const Text(
                'Scan Label',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.verified_user, color: AppColors.navy, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Officer Credentials',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.displayName ?? user?.email ?? 'Enforcement Officer',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy),
              ),
              const SizedBox(height: 2),
              Text(
                user?.email ?? '',
                style: const TextStyle(fontSize: 12, color: AppColors.slateMuted),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield, size: 14, color: AppColors.navy),
                    const SizedBox(width: 6),
                    Text(
                      'ROLE: ${user?.role.toUpperCase() ?? 'INSPECTOR'}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.navy),
                    ),
                  ],
                ),
              ),
              if (user?.badgeNumber != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Badge Identifier: ${user!.badgeNumber}',
                  style: const TextStyle(fontSize: 12, color: AppColors.slate),
                ),
              ],
              if (user?.district != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Assigned Jurisdiction: ${user!.district}',
                  style: const TextStyle(fontSize: 12, color: AppColors.slate),
                ),
              ],
              const Divider(height: 24),
              const Text(
                'Logging out will disable inspector raid features and return to citizen mode.',
                style: TextStyle(fontSize: 12, color: AppColors.slateMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Dismiss'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.nonCompliant,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Command Engine Endpoint',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Specify the Legal Metrology backend API URL:',
              style: TextStyle(fontSize: 12.5, color: AppColors.slateMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: 'http://10.0.2.2:8000',
                labelText: 'Base URL',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '• 10.0.2.2 for Android Emulator\n• 127.0.0.1 for ADB Reverse\n• LAN IP for Physical Testing\nRestart the application after changing.',
              style: TextStyle(fontSize: 11, color: AppColors.slateMuted, height: 1.4),
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
            child: const Text('Save Endpoint'),
          ),
        ],
      ),
    );
    if (url != null && url.isNotEmpty && url != app.api.baseUrl) {
      await app.setBaseUrl(url);
      if (context.mounted) {
        showSnack(context, 'Endpoint updated. Restart app to establish new session.');
      }
    }
  }
}

class _ConnectivityPill extends StatelessWidget {
  const _ConnectivityPill({required this.app, required this.onTap});

  final AppState app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isOffline = !app.backendReachable || !app.hasNetwork;
    final int queueCount = app.queue.length;

    Color badgeColor;
    String label;
    IconData icon;

    if (queueCount > 0) {
      badgeColor = const Color(0xFFF59E0B);
      icon = Icons.cloud_upload;
      label = '$queueCount QUEUED';
    } else if (isOffline) {
      badgeColor = const Color(0xFFEF4444);
      icon = Icons.cloud_off;
      label = 'OFFLINE';
    } else {
      badgeColor = const Color(0xFF4ADE80);
      icon = Icons.fiber_manual_record;
      label = 'ONLINE';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: badgeColor.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: badgeColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: badgeColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
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

    return RefreshIndicator(
      onRefresh: app.refreshConnectivity,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          // System Notice if Offline
          if (!app.backendReachable)
            StatusBanner(
              icon: Icons.cloud_off,
              message: app.hasNetwork
                  ? 'Server unreachable at ${app.api.baseUrl} — scans stored securely on disk'
                  : 'No network interface detected — offline queue actively archiving scans',
              color: AppColors.saffron,
              action: TextButton(
                onPressed: onEditBaseUrl,
                child: const Text('Change Endpoint'),
              ),
            ),
          if (app.queue.isNotEmpty)
            StatusBanner(
              icon: app.queue.syncing ? Icons.sync : Icons.cloud_queue,
              message: app.queue.syncing
                  ? 'Synchronizing ${app.queue.length} offline scans with central database...'
                  : '${app.queue.length} scan(s) archived locally on device waiting for sync',
              color: AppColors.navy,
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

          // Executive Hero Welcome Card
          _ExecutiveWelcomeCard(app: app),

          // 4-Stat Metric Cards with ZERO overlap
          _TelemetryStatsGrid(app: app, onNavigateTab: onNavigateTab),

          // Hero Primary Scan Action
          _HeroScannerCTA(onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraScreen()),
            );
          }),

          // Section 1: Enforcement & Compliance Tools
          SectionHeader(
            title: 'REGULATORY ENFORCEMENT DESK',
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
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.navy,
                  title: 'Inspector Batch Raid Session',
                  subtitle:
                      'Audit and link multiple suspect commodities under a single operational raid identifier.',
                  badgeText: app.isInspector ? 'OFFICER' : null,
                  badgeColor: AppColors.navy,
                  onTap: () => onNavigateTab(2),
                ),
                const SizedBox(height: 8),
                QuickActionTile(
                  icon: Icons.map_outlined,
                  color: AppColors.slate,
                  title: 'Violation Spatial Hotspots & Analytics',
                  subtitle:
                      'National PostGIS geo-binned violation heatmap, repeat offender registry & CSV export.',
                  badgeText: 'INTELLIGENCE',
                  badgeColor: AppColors.gold,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                  ),
                ),
                const SizedBox(height: 8),
                QuickActionTile(
                  icon: Icons.fact_check_outlined,
                  color: AppColors.indiaGreen,
                  title: 'Field Verification Protocol Checklist',
                  subtitle:
                      '8-point physical package audit: label adherence, dual pricing, PIN code & SI units.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChecklistSheet()),
                  ),
                ),
                const SizedBox(height: 8),
                QuickActionTile(
                  icon: Icons.gavel_outlined,
                  color: AppColors.gold,
                  title: 'LM(PC) Rules, 2011 Statutory Code',
                  subtitle:
                      'Searchable legal standards: Rule 6 declarations, font height tables, Section 36 penalties.',
                  onTap: () => onNavigateTab(3),
                ),
              ],
            ),
          ),

          // Section 2: Consumer Protection & Offline Hub
          SectionHeader(
            title: 'CONSUMER GRIEVANCES & SYNC HUB',
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
                    icon: Icons.support_agent_outlined,
                    color: AppColors.navy,
                    title: 'NCH 1915 Desk',
                    subtitle: 'Escalate to CCPA & e-Daakhil consumer court',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GrievanceSheet()),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: QuickActionTile(
                    icon: Icons.cloud_sync_outlined,
                    color: AppColors.slate,
                    title: 'Offline Queue',
                    subtitle: '${app.queue.length} pending local captures',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QueueSheet()),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Section 3: Recent Activity Feed
          SectionHeader(
            title: 'RECENT INSPECTION ARCHIVE',
            actionLabel: 'View All (${app.localScanIds.length})',
            onAction: () => onNavigateTab(1),
          ),
          _RecentInspectionArchive(app: app),

          // Institutional Statutory Advisory Card
          const _DepartmentAdvisoryCard(),

          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                const StateEmblemMark(size: 24, color: AppColors.slateMuted),
                const SizedBox(height: 6),
                const Text(
                  'Department of Consumer Affairs · Legal Metrology Division',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slateMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ministry of Consumer Affairs, Food & Public Distribution · Government of India',
                  style: TextStyle(fontSize: 9.5, color: AppColors.slateLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutiveWelcomeCard extends StatelessWidget {
  const _ExecutiveWelcomeCard({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final isInspector = app.isInspector;
    final user = app.user;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040B2545),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isInspector
                  ? AppColors.navy.withValues(alpha: 0.1)
                  : AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isInspector
                    ? AppColors.navy.withValues(alpha: 0.25)
                    : AppColors.gold.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                isInspector ? Icons.verified_user : Icons.shield_outlined,
                color: isInspector ? AppColors.navy : AppColors.gold,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isInspector
                            ? AppColors.navy.withValues(alpha: 0.08)
                            : AppColors.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isInspector
                              ? AppColors.navy.withValues(alpha: 0.2)
                              : AppColors.gold.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        isInspector ? 'OFFICIAL ENFORCEMENT INSPECTOR' : 'CITIZEN VERIFICATION DESK',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: isInspector ? AppColors.navy : AppColors.gold,
                        ),
                      ),
                    ),
                    if (user?.badgeNumber != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '#${user!.badgeNumber}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slateMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  app.isLoggedIn
                      ? 'Welcome, ${user?.displayName ?? 'Officer'}'
                      : 'National Legal Metrology Portal',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.district != null
                      ? 'Jurisdiction: District ${user!.district}'
                      : 'Packaged commodities compliance surveillance',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.slateMuted,
                    height: 1.25,
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

class _TelemetryStatsGrid extends StatelessWidget {
  const _TelemetryStatsGrid({required this.app, required this.onNavigateTab});

  final AppState app;
  final void Function(int) onNavigateTab;

  @override
  Widget build(BuildContext context) {
    // Two clean rows of 2 cards each. Generous negative space, ZERO overlapping text.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DashboardStatCard(
                  title: 'Scans Audited',
                  value: '${app.localScanIds.length}',
                  icon: Icons.description_outlined,
                  color: AppColors.navy,
                  subtitle: 'On this device',
                  onTap: () => onNavigateTab(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DashboardStatCard(
                  title: 'Offline Queue',
                  value: '${app.queue.length}',
                  icon: Icons.cloud_queue_outlined,
                  color: app.queue.isNotEmpty ? AppColors.saffron : AppColors.slate,
                  subtitle: app.queue.isNotEmpty ? 'Pending server sync' : 'All records synced',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QueueSheet()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DashboardStatCard(
                  title: 'Raid Batches',
                  value: '${app.sessionIds.length}',
                  icon: Icons.badge_outlined,
                  color: AppColors.navy,
                  subtitle: 'Market raid operations',
                  onTap: () => onNavigateTab(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DashboardStatCard(
                  title: 'Core Engine',
                  value: app.backendReachable ? 'Online' : 'Offline',
                  icon: app.backendReachable ? Icons.check_circle_outline : Icons.dns_outlined,
                  color: app.backendReachable ? AppColors.compliant : AppColors.nonCompliant,
                  subtitle: 'Tap for diagnostics',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DiagnosticsSheet()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroScannerCTA extends StatelessWidget {
  const _HeroScannerCTA({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180B2545),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.document_scanner, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LEGAL METROLOGY (PC) RULES 2011',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFDE68A),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Start Compliance Label Scan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Point at packaged commodity to extract declarations, verify MRP, Unit Sale Price & font size.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentInspectionArchive extends StatelessWidget {
  const _RecentInspectionArchive({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final recentIds = app.localScanIds.reversed.take(3).toList();

    if (recentIds.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.inventory_outlined, size: 36, color: AppColors.slateLight),
            const SizedBox(height: 10),
            const Text(
              'No inspection records yet',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.navy),
            ),
            const SizedBox(height: 4),
            const Text(
              'Initiate a label scan above to record compliance evidence.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: AppColors.slateMuted),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final id in recentIds) _RecentInspectionCard(scanId: id),
        ],
      ),
    );
  }
}

class _RecentInspectionCard extends StatefulWidget {
  const _RecentInspectionCard({required this.scanId});

  final String scanId;

  @override
  State<_RecentInspectionCard> createState() => _RecentInspectionCardState();
}

class _RecentInspectionCardState extends State<_RecentInspectionCard> {
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
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy),
            ),
            SizedBox(width: 12),
            Text('Fetching scan record…', style: TextStyle(fontSize: 12, color: AppColors.slateMuted)),
          ],
        ),
      );
    }

    final res = _result;
    if (res == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, size: 20, color: AppColors.slateLight),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Record #${widget.scanId.substring(0, 8)} (Archived on device)',
                style: const TextStyle(fontSize: 12, color: AppColors.slate),
              ),
            ),
          ],
        ),
      );
    }

    final color = verdictColor(res.verdict, scheme);
    final bgColor = verdictBgColor(res.verdict);
    final borderColor = verdictBorderColor(res.verdict);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ScanResultScreen(result: res, refreshable: true),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(verdictIcon(res.verdict), color: color, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        verdictLabel(res.verdict),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ID: ${res.scanId.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        res.summary ??
                            (res.violations.isNotEmpty
                                ? '${res.violations.length} statutory rule violation(s) identified'
                                : 'All mandatory declarations verified successfully'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.slateMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 18, color: AppColors.slateLight),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DepartmentAdvisoryCard extends StatelessWidget {
  const _DepartmentAdvisoryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.goldLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gavel, color: AppColors.gold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Statutory Advisory: Unit Sale Price (USP) Rule 6(1)(da)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Under the amended Legal Metrology (Packaged Commodities) Rules, all packages greater than 1 kg or 1 L must declare the Unit Sale Price (₹ per g or ₹ per ml) rounded to two decimal places.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.brown.shade800,
                    height: 1.35,
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
    final user = app.user;

    return Drawer(
      child: Column(
        children: [
          const TricolorStripe(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 20),
            color: AppColors.navy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StateEmblemMark(size: 38, color: Color(0xFFD4AF37)),
                const SizedBox(height: 12),
                Text(
                  app.isLoggedIn
                      ? (user?.displayName ?? 'Inspector')
                      : 'SatyaLabel Portal',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  app.isLoggedIn
                      ? (user?.email ?? '')
                      : 'Department of Consumer Affairs',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    app.isLoggedIn
                        ? 'ROLE: ${user?.role.toUpperCase() ?? 'INSPECTOR'}'
                        : 'CITIZEN VERIFICATION MODE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.space_dashboard_outlined, color: AppColors.navy, size: 20),
                  title: const Text('Command Dashboard', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  onTap: () {
                    Navigator.pop(context);
                    onNavigateTab(0);
                  },
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.document_scanner_outlined, color: AppColors.navy, size: 20),
                  title: const Text('AI Label Scanner', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CameraScreen()),
                    );
                  },
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.description_outlined, color: AppColors.navy, size: 20),
                  title: const Text('Inspection Archive', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${app.localScanIds.length}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.navy),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onNavigateTab(1);
                  },
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.badge_outlined, color: AppColors.navy, size: 20),
                  title: const Text('Batch Raid Sessions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  onTap: () {
                    Navigator.pop(context);
                    onNavigateTab(2);
                  },
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.analytics_outlined, color: AppColors.navy, size: 20),
                  title: const Text('Spatial Hotspots & Heatmap', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                    );
                  },
                ),
                const Divider(height: 16),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.fact_check_outlined, color: AppColors.slate, size: 20),
                  title: const Text('Field Inspection Protocol', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChecklistSheet()),
                    );
                  },
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.gavel_outlined, color: AppColors.slate, size: 20),
                  title: const Text('LM(PC) Rules 2011 Standards', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  onTap: () {
                    Navigator.pop(context);
                    onNavigateTab(3);
                  },
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.support_agent_outlined, color: AppColors.slate, size: 20),
                  title: const Text('Consumer Grievance (NCH 1915)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GrievanceSheet()),
                    );
                  },
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.cloud_sync_outlined, color: AppColors.slate, size: 20),
                  title: const Text('Offline Queue Manager', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  trailing: app.queue.isNotEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.saffron,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${app.queue.length}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
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
                  dense: true,
                  leading: const Icon(Icons.tune_outlined, color: AppColors.slate, size: 20),
                  title: const Text('Sensor & API Diagnostics', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DiagnosticsSheet()),
                    );
                  },
                ),
                const Divider(height: 16),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.dns_outlined, color: AppColors.slateMuted, size: 20),
                  title: const Text('Backend Endpoint', style: TextStyle(fontSize: 12.5)),
                  subtitle: Text(app.api.baseUrl, style: const TextStyle(fontSize: 10, color: AppColors.slateMuted)),
                  onTap: () {
                    Navigator.pop(context);
                    onEditBaseUrl();
                  },
                ),
                ListTile(
                  dense: true,
                  leading: Icon(
                    app.isLoggedIn ? Icons.logout : Icons.login,
                    color: app.isLoggedIn ? AppColors.nonCompliant : AppColors.navy,
                    size: 20,
                  ),
                  title: Text(
                    app.isLoggedIn ? 'Log Out of Officer Session' : 'Inspector Login',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: app.isLoggedIn ? AppColors.nonCompliant : AppColors.navy,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onAuthPressed();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
