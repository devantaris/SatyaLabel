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

  int _mapTabToStackIndex(int tabIndex, AppPersona persona) {
    if (tabIndex == 0) return 0;
    return switch (persona) {
      AppPersona.consumer => switch (tabIndex) {
          1 => 1, // History / My Scans
          2 => 5, // 1915 Helpline / Grievance
          3 => 3, // Consumer Rights / Rules
          _ => 0,
        },
      AppPersona.citizen => switch (tabIndex) {
          1 => 1, // Evidence Log
          2 => 3, // LM(PC) Rules
          3 => 5, // Grievance Desk
          _ => 0,
        },
      AppPersona.inspector => switch (tabIndex) {
          1 => 2, // Batch Raids
          2 => 4, // Spatial Radar
          3 => 3, // Statutory Standards
          _ => 0,
        },
    };
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(108),
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
            _PersonaSelectorBar(
              activePersona: app.activePersona,
              onSelectPersona: (p) {
                app.setActivePersona(p);
                setState(() => _selectedTabIndex = 0);
              },
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
        index: _mapTabToStackIndex(_selectedTabIndex, app.activePersona),
        children: [
          _ActivePersonaDashboardView(
            onNavigateTab: _navigateToTab,
            onEditBaseUrl: () => _editBaseUrl(context, app),
          ),
          const HistoryScreen(),
          const BatchSessionsScreen(),
          const RulesSheet(),
          const AnalyticsScreen(),
          const GrievanceSheet(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (i) => setState(() => _selectedTabIndex = i),
        destinations: switch (app.activePersona) {
          AppPersona.consumer => const [
              NavigationDestination(
                icon: Icon(Icons.shopping_bag_outlined),
                selectedIcon: Icon(Icons.shopping_bag),
                label: 'Shopper',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'My Scans',
              ),
              NavigationDestination(
                icon: Icon(Icons.phone_in_talk_outlined),
                selectedIcon: Icon(Icons.phone_in_talk),
                label: '1915 Help',
              ),
              NavigationDestination(
                icon: Icon(Icons.verified_user_outlined),
                selectedIcon: Icon(Icons.verified_user),
                label: 'Rights',
              ),
            ],
          AppPersona.citizen => const [
              NavigationDestination(
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check),
                label: 'Audit Hub',
              ),
              NavigationDestination(
                icon: Icon(Icons.description_outlined),
                selectedIcon: Icon(Icons.description),
                label: 'Evidence',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: 'LM Rules',
              ),
              NavigationDestination(
                icon: Icon(Icons.report_outlined),
                selectedIcon: Icon(Icons.report),
                label: 'Grievance',
              ),
            ],
          AppPersona.inspector => const [
              NavigationDestination(
                icon: Icon(Icons.space_dashboard_outlined),
                selectedIcon: Icon(Icons.space_dashboard),
                label: 'Command',
              ),
              NavigationDestination(
                icon: Icon(Icons.badge_outlined),
                selectedIcon: Icon(Icons.badge),
                label: 'Raids',
              ),
              NavigationDestination(
                icon: Icon(Icons.radar_outlined),
                selectedIcon: Icon(Icons.radar),
                label: 'Radar',
              ),
              NavigationDestination(
                icon: Icon(Icons.gavel_outlined),
                selectedIcon: Icon(Icons.gavel),
                label: 'Standards',
              ),
            ],
        },
      ),
      floatingActionButton: _selectedTabIndex == 0
          ? switch (app.activePersona) {
              AppPersona.consumer => FloatingActionButton.extended(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CameraScreen()),
                  ),
                  backgroundColor: AppColors.consumerPrimary,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  icon: const Icon(Icons.qr_code_scanner, size: 19),
                  label: const Text(
                    'Check Price',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              AppPersona.citizen => FloatingActionButton.extended(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CameraScreen()),
                  ),
                  backgroundColor: AppColors.citizenPrimary,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  icon: const Icon(Icons.document_scanner, size: 19),
                  label: const Text(
                    'Audit Label',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              AppPersona.inspector => FloatingActionButton.extended(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CameraScreen()),
                  ),
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  icon: const Icon(Icons.shield, size: 19),
                  label: const Text(
                    'Execute Raid',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
            }
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

class _ActivePersonaDashboardView extends StatelessWidget {
  const _ActivePersonaDashboardView({
    required this.onNavigateTab,
    required this.onEditBaseUrl,
  });

  final void Function(int) onNavigateTab;
  final VoidCallback onEditBaseUrl;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return switch (app.activePersona) {
      AppPersona.consumer => _ConsumerDashboardTabView(
          app: app,
          onNavigateTab: onNavigateTab,
          onEditBaseUrl: onEditBaseUrl,
        ),
      AppPersona.citizen => _CitizenDashboardTabView(
          app: app,
          onNavigateTab: onNavigateTab,
          onEditBaseUrl: onEditBaseUrl,
        ),
      AppPersona.inspector => _InspectorDashboardTabView(
          app: app,
          onNavigateTab: onNavigateTab,
          onEditBaseUrl: onEditBaseUrl,
        ),
    };
  }
}

class _PersonaSelectorBar extends StatelessWidget {
  const _PersonaSelectorBar({
    required this.activePersona,
    required this.onSelectPersona,
  });

  final AppPersona activePersona;
  final ValueChanged<AppPersona> onSelectPersona;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        padding: const EdgeInsets.all(2.5),
        child: Row(
          children: [
            _PersonaSegment(
              title: 'Consumer',
              icon: Icons.shopping_bag_outlined,
              isSelected: activePersona == AppPersona.consumer,
              activeBg: AppColors.consumerPrimary,
              activeColor: Colors.white,
              onTap: () => onSelectPersona(AppPersona.consumer),
            ),
            _PersonaSegment(
              title: 'Citizen',
              icon: Icons.person_outline,
              isSelected: activePersona == AppPersona.citizen,
              activeBg: AppColors.citizenPrimary,
              activeColor: Colors.white,
              onTap: () => onSelectPersona(AppPersona.citizen),
            ),
            _PersonaSegment(
              title: 'Inspector',
              icon: Icons.shield_outlined,
              isSelected: activePersona == AppPersona.inspector,
              activeBg: const Color(0xFFD4AF37),
              activeColor: AppColors.navyDark,
              onTap: () => onSelectPersona(AppPersona.inspector),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonaSegment extends StatelessWidget {
  const _PersonaSegment({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.activeBg,
    required this.activeColor,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isSelected;
  final Color activeBg;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? activeColor : Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 5),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? activeColor : Colors.white.withValues(alpha: 0.75),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- 1. CONSUMER DASHBOARD
class _ConsumerDashboardTabView extends StatelessWidget {
  const _ConsumerDashboardTabView({
    required this.app,
    required this.onNavigateTab,
    required this.onEditBaseUrl,
  });

  final AppState app;
  final void Function(int) onNavigateTab;
  final VoidCallback onEditBaseUrl;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: app.refreshConnectivity,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (!app.backendReachable)
            StatusBanner(
              icon: Icons.cloud_off,
              message: app.hasNetwork
                  ? 'Server unreachable at ${app.api.baseUrl} — scans stored securely on disk'
                  : 'No network detected — offline queue will store price checks locally',
              color: AppColors.saffron,
              action: TextButton(onPressed: onEditBaseUrl, child: const Text('Change Endpoint')),
            ),

          // Consumer Masthead
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.consumerBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.consumerBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.consumerPrimary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_bag, size: 11, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'CONSUMER SHIELD · JAGO GRAHAK JAGO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.consumerBorder),
                      ),
                      child: const Text(
                        'FREE PUBLIC ACCESS',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.consumerPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Smart Shopper Protection',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.consumerPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Verify packaging before you buy. Check if printed MRP has been altered, verify the Unit Sale Price (USP), and confirm product freshness.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.consumerPrimary.withValues(alpha: 0.85),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),

          // Consumer Telemetry (Price, USP, Expiry, 1915)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DashboardStatCard(
                        title: 'MRP Overcharge',
                        value: 'Zero Tolerance',
                        subtitle: 'Illegal under Section 36',
                        icon: Icons.price_check,
                        color: AppColors.consumerPrimary,
                        onTap: () => _showMrpGuideDialog(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DashboardStatCard(
                        title: 'Unit Sale Price',
                        value: '₹ per 100g / ml',
                        subtitle: 'Detect shrinkflation',
                        icon: Icons.scale,
                        color: AppColors.slate,
                        onTap: () => _showUspGuideDialog(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DashboardStatCard(
                        title: 'Expiry Alert',
                        value: 'Best Before',
                        subtitle: 'Perishable freshness check',
                        icon: Icons.event_available,
                        color: AppColors.saffron,
                        onTap: () => _showExpiryGuideDialog(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DashboardStatCard(
                        title: 'Helpline 1915',
                        value: 'Toll-Free Desk',
                        subtitle: 'Immediate dispute redressal',
                        icon: Icons.support_agent,
                        color: AppColors.navy,
                        onTap: () => _show1915Dialog(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Consumer Hero Scanner CTA
          _ConsumerHeroScannerCTA(onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraScreen()),
            );
          }),

          // Consumer Action Desk
          SectionHeader(
            title: 'CONSUMER GRIEVANCE & ASSISTANCE DESK',
            actionLabel: 'Call 1915',
            onAction: () => _show1915Dialog(context),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                QuickActionTile(
                  icon: Icons.phone_in_talk,
                  color: AppColors.consumerPrimary,
                  title: 'National Consumer Helpline (NCH 1915)',
                  subtitle: 'Call toll-free 1915 or send SMS / WhatsApp to 8800001915 for immediate consumer dispute resolution.',
                  badgeText: 'TOLL-FREE',
                  badgeColor: AppColors.consumerPrimary,
                  onTap: () => _show1915Dialog(context),
                ),
                const SizedBox(height: 8),
                QuickActionTile(
                  icon: Icons.language,
                  color: AppColors.slate,
                  title: 'Lodge Grievance on INGRAM Portal',
                  subtitle: 'Register formal complaint online at consumerhelpline.gov.in and attach SatyaLabel scan evidence.',
                  badgeText: 'ONLINE',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GrievanceSheet()),
                  ),
                ),
                const SizedBox(height: 8),
                QuickActionTile(
                  icon: Icons.verified_user_outlined,
                  color: AppColors.gold,
                  title: '6 Mandatory Consumer Rights (2019 Act)',
                  subtitle: 'Right to Safety, Right to Information, Right to Choice, Right to Redressal, and Right to Education.',
                  onTap: () => _showConsumerRightsDialog(context),
                ),
                const SizedBox(height: 8),
                QuickActionTile(
                  icon: Icons.menu_book_outlined,
                  color: AppColors.navy,
                  title: 'Packaging Rules in Plain Language',
                  subtitle: 'Essential checklist: what manufacturers must legally declare on packaged groceries and personal care goods.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RulesSheet()),
                  ),
                ),
              ],
            ),
          ),

          // Recent Scans
          SectionHeader(
            title: 'YOUR VERIFIED PRODUCTS',
            actionLabel: 'View All (${app.localScanIds.length})',
            onAction: () => onNavigateTab(1),
          ),
          _RecentInspectionArchive(app: app),

          const SizedBox(height: 20),
          const _ConsumerRightsFooter(),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- 2. CITIZEN AUDITOR DASHBOARD
class _CitizenDashboardTabView extends StatelessWidget {
  const _CitizenDashboardTabView({
    required this.app,
    required this.onNavigateTab,
    required this.onEditBaseUrl,
  });

  final AppState app;
  final void Function(int) onNavigateTab;
  final VoidCallback onEditBaseUrl;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: app.refreshConnectivity,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (!app.backendReachable)
            StatusBanner(
              icon: Icons.cloud_off,
              message: app.hasNetwork
                  ? 'Server unreachable at ${app.api.baseUrl} — audits stored securely on disk'
                  : 'No network detected — offline queue will store audits locally',
              color: AppColors.saffron,
              action: TextButton(onPressed: onEditBaseUrl, child: const Text('Change Endpoint')),
            ),
          if (app.queue.isNotEmpty)
            StatusBanner(
              icon: app.queue.syncing ? Icons.sync : Icons.cloud_queue,
              message: app.queue.syncing
                  ? 'Synchronizing ${app.queue.length} citizen audit records...'
                  : '${app.queue.length} audit(s) waiting for crowdsource sync',
              color: AppColors.citizenPrimary,
              action: TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const QueueSheet()));
                },
                child: const Text('View Queue'),
              ),
            ),

          // Citizen Auditor Masthead
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.citizenBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.citizenBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.citizenPrimary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person, size: 11, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'CITIZEN METROLOGY AUDITOR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.citizenBorder),
                      ),
                      child: const Text(
                        'CROWDSOURCED VIGILANCE',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.citizenPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Community Market Vigilance',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.citizenPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Empower civic enforcement. Audit retail shelves, record photographic & GPS evidence of non-compliant labels, and generate tamper-evident PDF dossiers for consumer forums.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.slate,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),

          // Citizen Telemetry Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DashboardStatCard(
                        title: 'Audits Logged',
                        value: '${app.localScanIds.length}',
                        subtitle: 'Local shelf audits',
                        icon: Icons.fact_check_outlined,
                        color: AppColors.citizenPrimary,
                        onTap: () => onNavigateTab(1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DashboardStatCard(
                        title: 'Offline Queue',
                        value: '${app.queue.length}',
                        subtitle: app.queue.isNotEmpty ? 'Pending server sync' : 'All audits synced',
                        icon: Icons.cloud_queue_outlined,
                        color: app.queue.isNotEmpty ? AppColors.saffron : AppColors.slate,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QueueSheet())),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DashboardStatCard(
                        title: 'Legal Standards',
                        value: '8 Clauses',
                        subtitle: 'Rule 6(1) declarations',
                        icon: Icons.menu_book_outlined,
                        color: AppColors.gold,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RulesSheet())),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DashboardStatCard(
                        title: 'Helpline 1915',
                        value: 'Active Desk',
                        subtitle: 'e-Daakhil filing guide',
                        icon: Icons.support_agent_outlined,
                        color: AppColors.navy,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GrievanceSheet())),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Citizen Hero Scanner CTA
          _CitizenHeroScannerCTA(onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraScreen()),
            );
          }),

          // Citizen Enforcement Desk
          SectionHeader(
            title: 'CROWDSOURCED ENFORCEMENT DESK',
            actionLabel: 'Standards',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RulesSheet()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                QuickActionTile(
                  icon: Icons.picture_as_pdf_outlined,
                  color: AppColors.citizenPrimary,
                  title: 'Generate PDF Evidence Dossier',
                  subtitle: 'Export tamper-evident reports with GPS coordinates, timestamps, and statutory citations for consumer disputes.',
                  badgeText: 'SHA-256',
                  badgeColor: AppColors.citizenPrimary,
                  onTap: () => onNavigateTab(1),
                ),
                const SizedBox(height: 8),
                QuickActionTile(
                  icon: Icons.balance_outlined,
                  color: AppColors.gold,
                  title: 'e-Daakhil Online Consumer Court Submission',
                  subtitle: 'Step-by-step guide to filing formal cases against deceptive packaging, dual pricing, and slack-fill at edaakhil.nic.in.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GrievanceSheet()),
                  ),
                ),
                const SizedBox(height: 8),
                QuickActionTile(
                  icon: Icons.forward_to_inbox_outlined,
                  color: AppColors.slate,
                  title: 'Notice to State Legal Metrology Controller',
                  subtitle: 'Format standardized complaint letters to trigger district inspection raids under Section 15 of the LM Act.',
                  onTap: () => _showStateControllerGuideDialog(context),
                ),
                const SizedBox(height: 8),
                QuickActionTile(
                  icon: Icons.menu_book_outlined,
                  color: AppColors.navy,
                  title: 'Search LM(PC) Rules 2011 Standards',
                  subtitle: 'Full legal wording of mandatory declarations: manufacturer address, generic names, net weights, and font tables.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RulesSheet()),
                  ),
                ),
              ],
            ),
          ),

          // Recent Audits
          SectionHeader(
            title: 'RECENT AUDIT EVIDENCE LOG',
            actionLabel: 'View All (${app.localScanIds.length})',
            onAction: () => onNavigateTab(1),
          ),
          _RecentInspectionArchive(app: app),

          const SizedBox(height: 20),
          const _DepartmentAdvisoryCard(),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- 3. INSPECTOR DASHBOARD
class _InspectorDashboardTabView extends StatelessWidget {
  const _InspectorDashboardTabView({
    required this.app,
    required this.onNavigateTab,
    required this.onEditBaseUrl,
  });

  final AppState app;
  final void Function(int) onNavigateTab;
  final VoidCallback onEditBaseUrl;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: app.refreshConnectivity,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (!app.backendReachable)
            StatusBanner(
              icon: Icons.cloud_off,
              message: app.hasNetwork
                  ? 'Server unreachable at ${app.api.baseUrl} — raids stored securely on disk'
                  : 'No network detected — offline queue actively archiving raids',
              color: AppColors.saffron,
              action: TextButton(onPressed: onEditBaseUrl, child: const Text('Change Endpoint')),
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
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const QueueSheet()));
                },
                child: const Text('View Queue'),
              ),
            ),

          // Officer Access Warning if Not Logged In
          if (!app.isInspector)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.goldLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings, color: AppColors.gold, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inspector Mode Preview',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.gold),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Official credentials required to enable digital badge stamping & batch raid sessions.',
                          style: TextStyle(fontSize: 11, color: AppColors.slate),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: const Text('Officer Sign In', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),

          // Executive Welcome Card
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
                  subtitle: 'Audit and link multiple suspect commodities under a single operational raid identifier.',
                  badgeText: app.isInspector ? 'OFFICER' : 'LOCKED',
                  badgeColor: AppColors.navy,
                  onTap: () {
                    if (app.isInspector) {
                      onNavigateTab(2);
                    } else {
                      _showOfficerGateDialog(context);
                    }
                  },
                ),
                const SizedBox(height: 8),
                QuickActionTile(
                  icon: Icons.map_outlined,
                  color: AppColors.slate,
                  title: 'Violation Spatial Hotspots & Radar',
                  subtitle: 'National PostGIS geo-binned violation heatmap, repeat offender registry & CSV export.',
                  badgeText: 'INTELLIGENCE',
                  badgeColor: AppColors.gold,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                  ),
                ),
                const SizedBox(height: 8),
                QuickActionTile(
                  icon: Icons.calculate_outlined,
                  color: AppColors.gold,
                  title: 'Section 36 & 48 Penalty Compounding Calculator',
                  subtitle: 'Instant calculator for 1st offense (₹25k), 2nd offense (₹50k), and subsequent compounding limits.',
                  badgeText: 'LEGAL ACT',
                  badgeColor: AppColors.gold,
                  onTap: () => _showCompoundingCalculatorDialog(context),
                ),
                const SizedBox(height: 8),
                QuickActionTile(
                  icon: Icons.fact_check_outlined,
                  color: AppColors.indiaGreen,
                  title: 'Field Verification Protocol Checklist',
                  subtitle: '8-point physical package audit: label adherence, dual pricing, PIN code & SI units.',
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
                  subtitle: 'Searchable legal standards: Rule 6 declarations, font height tables, Section 36 penalties.',
                  onTap: () => onNavigateTab(3),
                ),
              ],
            ),
          ),

          // Section 2: Consumer Protection & Offline Hub
          SectionHeader(
            title: 'COMMAND TOOLS & OFFLINE HUB',
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

          const _DepartmentAdvisoryCard(),
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

class _ConsumerHeroScannerCTA extends StatelessWidget {
  const _ConsumerHeroScannerCTA({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.consumerPrimary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18065F46),
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
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
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
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'INSTANT SHOPPER VERIFIER',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Check Price & Expiry Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Point camera at product label or price sticker to verify MRP limits & Best Before date.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
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

class _CitizenHeroScannerCTA extends StatelessWidget {
  const _CitizenHeroScannerCTA({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.citizenPrimary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x181E40AF),
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
                    color: Colors.white.withValues(alpha: 0.15),
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
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'GPS EVIDENCE STAMP ACTIVE',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Audit Package & Record Evidence',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Captures full 8-clause Legal Metrology declarations, GPS location & SHA-256 evidence hash.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
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

class _ConsumerRightsFooter extends StatelessWidget {
  const _ConsumerRightsFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.consumerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.consumerBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield, color: AppColors.consumerPrimary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Consumer Protection Act, 2019 Guarantee',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.consumerPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Every consumer has the statutory right to be informed about the quality, quantity, potency, purity, standard and price of goods to protect against unfair trade practices.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.consumerPrimary.withValues(alpha: 0.9),
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

// ------------------------------------------------------------- STATUTORY & ROLE DIALOGS
void _show1915Dialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.consumerPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.phone_in_talk, color: AppColors.consumerPrimary, size: 20),
          ),
          const SizedBox(width: 10),
          const Text('National Consumer Helpline', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The Department of Consumer Affairs operates the National Consumer Helpline for speedy grievance redressal:',
            style: TextStyle(fontSize: 12, color: AppColors.slate, height: 1.35),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.consumerBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.consumerBorder),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📞 Toll-Free Helpline: 1915', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.consumerPrimary)),
                SizedBox(height: 4),
                Text('💬 SMS / WhatsApp: 8800001915', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.slate)),
                SizedBox(height: 4),
                Text('🌐 Web Portal: consumerhelpline.gov.in', style: TextStyle(fontSize: 11.5, color: AppColors.slateMuted)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Keep your SatyaLabel scan ID or PDF report ready when lodging a complaint.',
            style: TextStyle(fontSize: 11, color: AppColors.slateMuted),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    ),
  );
}

void _showConsumerRightsDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('6 Mandatory Consumer Rights', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RightBullet(title: '1. Right to Safety', desc: 'Protection against goods hazardous to life and property.'),
            _RightBullet(title: '2. Right to Information', desc: 'Mandatory declaration of MRP, Net Weight, and Expiry date.'),
            _RightBullet(title: '3. Right to Choose', desc: 'Access to competitive variety without coercive dual pricing.'),
            _RightBullet(title: '4. Right to be Heard', desc: 'Consumer interests receive due consideration in appropriate forums.'),
            _RightBullet(title: '5. Right to Redressal', desc: 'Relief against unfair trade practices and restrictive trade practices.'),
            _RightBullet(title: '6. Right to Consumer Education', desc: 'Awareness campaigns under Jago Grahak Jago.'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Understood')),
      ],
    ),
  );
}

class _RightBullet extends StatelessWidget {
  const _RightBullet({required this.title, required this.desc});
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.navy)),
          const SizedBox(height: 1),
          Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.slateMuted)),
        ],
      ),
    );
  }
}

void _showMrpGuideDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('MRP & Overcharging Laws', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      content: const Text(
        'Under Rule 6(1)(e) of the Legal Metrology (Packaged Commodities) Rules, 2011:\n\n'
        '• No retailer can sell a packaged commodity at a price higher than the Maximum Retail Price (MRP).\n'
        '• The MRP must state "inclusive of all taxes".\n'
        '• Dual MRP stickers or pasting higher price stickers over manufacturer prints is punishable with fine up to ₹50,000 under Section 36.',
        style: TextStyle(fontSize: 12, color: AppColors.slate, height: 1.4),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Dismiss'))],
    ),
  );
}

void _showUspGuideDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Unit Sale Price (USP)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      content: const Text(
        'Under Rule 6(1)(da) (enforced Dec 2022):\n\n'
        '• Every package greater than 1 kg or 1 L must declare the unit price (₹ per g or ₹ per ml) rounded to two decimal places.\n'
        '• Packages sold by number must declare ₹ per item.\n'
        '• This allows consumers to compare different size variants and identify deceptive shrinkflation.',
        style: TextStyle(fontSize: 12, color: AppColors.slate, height: 1.4),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Dismiss'))],
    ),
  );
}

void _showExpiryGuideDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Expiry & Best Before Rules', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      content: const Text(
        'Under Rule 6(1)(g) of the LM(PC) Rules, 2011:\n\n'
        '• For all perishable commodities that may deteriorate, the "Best Before" or "Use By" date must be declared.\n'
        '• Selling expired packaged commodities is a critical offense that triggers immediate product seizure under Section 15 of the LM Act.',
        style: TextStyle(fontSize: 12, color: AppColors.slate, height: 1.4),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Dismiss'))],
    ),
  );
}

void _showCompoundingCalculatorDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Row(
        children: [
          Icon(Icons.calculate, color: AppColors.gold, size: 20),
          SizedBox(width: 8),
          Text('Section 36 & 48 Calculator', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Statutory Penalties under Section 36(1):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.navy)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• First Offence: Fine up to ₹25,000', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                SizedBox(height: 3),
                Text('• Second Offence: Fine up to ₹50,000', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.orange)),
                SizedBox(height: 3),
                Text('• Subsequent Offences: Fine up to ₹1,00,000 or imprisonment up to 1 year', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.nonCompliant)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text('Section 48 Compounding Provisions:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.navy)),
          const SizedBox(height: 4),
          const Text('Authorised Controller or Inspector may compound offences before or after prosecution proceedings upon payment of compounding sum.', style: TextStyle(fontSize: 11, color: AppColors.slateMuted, height: 1.3)),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ),
  );
}

void _showStateControllerGuideDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Report to State Controller', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      content: const Text(
        'To submit a citizen violation report to your State Legal Metrology Controller:\n\n'
        '1. Scan suspect product with SatyaLabel camera.\n'
        '2. Tap "Download PDF Evidence Dossier".\n'
        '3. Email the dossier along with store GPS location to the Controller of Legal Metrology in your state.\n'
        '4. The Inspector of the jurisdiction will conduct an inspection raid under Section 15.',
        style: TextStyle(fontSize: 12, color: AppColors.slate, height: 1.4),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Understood'))],
    ),
  );
}

void _showOfficerGateDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Row(
        children: [
          Icon(Icons.admin_panel_settings, color: AppColors.navy, size: 22),
          SizedBox(width: 8),
          Text('Officer Credentials Required', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
        ],
      ),
      content: const Text(
        'Batch Raid Sessions and digital seizure certificates require an authorized Legal Metrology Inspector badge.\n\n'
        'Please sign in with your official officer account provisioned by the department administrator.',
        style: TextStyle(fontSize: 12, color: AppColors.slate, height: 1.35),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
          },
          child: const Text('Sign In as Officer'),
        ),
      ],
    ),
  );
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
                    color: switch (app.activePersona) {
                      AppPersona.consumer => AppColors.consumerAccent.withValues(alpha: 0.35),
                      AppPersona.citizen => AppColors.citizenAccent.withValues(alpha: 0.35),
                      AppPersona.inspector => AppColors.inspectorAccent.withValues(alpha: 0.35),
                    },
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: switch (app.activePersona) {
                        AppPersona.consumer => AppColors.consumerBorder.withValues(alpha: 0.5),
                        AppPersona.citizen => AppColors.citizenBorder.withValues(alpha: 0.5),
                        AppPersona.inspector => AppColors.goldBorder.withValues(alpha: 0.5),
                      },
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        switch (app.activePersona) {
                          AppPersona.consumer => Icons.verified_user,
                          AppPersona.citizen => Icons.groups_2,
                          AppPersona.inspector => Icons.admin_panel_settings,
                        },
                        size: 11,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        switch (app.activePersona) {
                          AppPersona.consumer => 'CONSUMER / SHOPPER MODE',
                          AppPersona.citizen => 'CITIZEN AUDITOR MODE',
                          AppPersona.inspector => app.isLoggedIn
                              ? 'OFFICIAL: ${user?.role.toUpperCase() ?? 'INSPECTOR'}'
                              : 'INSPECTOR COMMAND (OFFICER)',
                        },
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SWITCH PERSPECTIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.slateMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _DrawerPersonaPill(
                      label: 'Consumer',
                      icon: Icons.verified_user_outlined,
                      isActive: app.activePersona == AppPersona.consumer,
                      activeColor: AppColors.consumerPrimary,
                      activeBg: AppColors.consumerBg,
                      onTap: () {
                        app.setActivePersona(AppPersona.consumer);
                      },
                    ),
                    const SizedBox(width: 6),
                    _DrawerPersonaPill(
                      label: 'Citizen',
                      icon: Icons.groups_2_outlined,
                      isActive: app.activePersona == AppPersona.citizen,
                      activeColor: AppColors.citizenPrimary,
                      activeBg: AppColors.citizenBg,
                      onTap: () {
                        app.setActivePersona(AppPersona.citizen);
                      },
                    ),
                    const SizedBox(width: 6),
                    _DrawerPersonaPill(
                      label: 'Inspector',
                      icon: Icons.shield_outlined,
                      isActive: app.activePersona == AppPersona.inspector,
                      activeColor: AppColors.inspectorPrimary,
                      activeBg: AppColors.inspectorBg,
                      onTap: () {
                        app.setActivePersona(AppPersona.inspector);
                      },
                    ),
                  ],
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
                    app.isLoggedIn
                        ? 'Log Out (${user?.displayName ?? user?.role.toUpperCase()})'
                        : 'Officer / Citizen Portal Login',
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

class _DrawerPersonaPill extends StatelessWidget {
  const _DrawerPersonaPill({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.activeBg,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final Color activeBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: isActive ? activeBg : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isActive ? activeColor : Colors.grey.shade300,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isActive ? activeColor : AppColors.slateMuted,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? activeColor : AppColors.slate,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

