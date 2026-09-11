import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'auth/login_screen.dart';
import 'batch/batch_sessions_screen.dart';
import 'history/history_screen.dart';
import 'scan/camera_screen.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().refreshConnectivity();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SatyaLabel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Backend URL',
            onPressed: () => _editBaseUrl(context, app),
          ),
          IconButton(
            icon: Icon(app.isLoggedIn ? Icons.logout : Icons.login),
            tooltip: app.isLoggedIn ? 'Log out' : 'Log in',
            onPressed: () => _onAuthPressed(context, app),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: app.refreshConnectivity,
        child: ListView(
          children: [
            if (!app.backendReachable)
              StatusBanner(
                icon: Icons.cloud_off,
                message: app.hasNetwork
                    ? 'Backend unreachable at ${app.api.baseUrl} — scans will be queued offline'
                    : 'No internet connection — scans will be queued offline',
                color: Colors.orange,
                action: TextButton(
                  onPressed: () => _editBaseUrl(context, app),
                  child: const Text('Change URL'),
                ),
              ),
            if (app.queue.isNotEmpty)
              StatusBanner(
                icon: app.queue.syncing ? Icons.sync : Icons.queue,
                message: app.queue.syncing
                    ? 'Syncing ${app.queue.length} queued scan(s)...'
                    : '${app.queue.length} scan(s) queued — will upload automatically'
                      '${app.queue.lastSyncError.isNotEmpty ? ' (${app.queue.lastSyncError})' : ''}',
                color: scheme.primary,
              ),
            const SizedBox(height: 8),
            if (app.isLoggedIn) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Signed in as ${app.user!.displayName}'
                  '${app.isInspector ? ' (Inspector)' : ' (Citizen)'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            _ActionCard(
              icon: Icons.camera_alt,
              color: scheme.primary,
              title: 'Scan a Label',
              subtitle: 'Point at a packaged-commodity label and check '
                  'Legal Metrology compliance instantly.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CameraScreen()),
              ),
            ),
            if (app.isInspector)
              _ActionCard(
                icon: Icons.inventory,
                color: scheme.tertiary,
                title: 'Batch Raid Session',
                subtitle: 'Scan multiple products under one session ID and '
                    'review the session history.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BatchSessionsScreen()),
                ),
              ),
            _ActionCard(
              icon: Icons.history,
              color: scheme.secondary,
              title: 'Scan History',
              subtitle: 'Your recent scans and their verdicts.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Explainable label compliance\nLegal Metrology (PC) Rules, 2011',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAuthPressed(BuildContext context, AppState app) async {
    if (app.isLoggedIn) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Log out?'),
          content: Text('Signed in as ${app.user!.email}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Log out'),
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
        title: const Text('Backend URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
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
              'Use 10.0.2.2 for the Android emulator, your computer\'s LAN IP '
              'for a physical device. Restart the app after changing.',
              style: TextStyle(fontSize: 12),
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

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
