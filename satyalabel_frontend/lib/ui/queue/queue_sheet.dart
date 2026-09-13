import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';

class QueueSheet extends StatefulWidget {
  const QueueSheet({super.key});

  @override
  State<QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends State<QueueSheet> {
  bool _manualSyncing = false;

  Future<void> _triggerSync(AppState app) async {
    setState(() => _manualSyncing = true);
    try {
      await app.refreshConnectivity();
      if (app.queue.isNotEmpty) {
        await app.queue.sync(app.api);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              app.queue.length == 0
                  ? 'All queued scans synchronized successfully!'
                  : 'Sync attempted: ${app.queue.length} scan(s) remaining.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _manualSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final isSyncing = app.queue.syncing || _manualSyncing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Queue & Sync'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isSyncing ? null : () => _triggerSync(app),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: app.queue.length == 0
                ? Colors.green.shade50
                : scheme.primaryContainer.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    app.queue.length == 0
                        ? Icons.cloud_done
                        : Icons.cloud_upload_outlined,
                    size: 40,
                    color: app.queue.length == 0 ? Colors.green.shade700 : scheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.queue.length == 0
                              ? 'Queue is Clear'
                              : '${app.queue.length} Scan(s) Queued Offline',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          app.queue.length == 0
                              ? 'All evidence captures have been synced to the server.'
                              : 'Scans captured without internet or backend connection are saved locally on disk.',
                          style: const TextStyle(fontSize: 12),
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
            'Connection & Synchronization Health',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    app.hasNetwork ? Icons.wifi : Icons.wifi_off,
                    color: app.hasNetwork ? Colors.green : Colors.red,
                  ),
                  title: const Text('Device Network Interface'),
                  subtitle: Text(app.hasNetwork
                      ? 'Connected (WiFi or Cellular)'
                      : 'No network connection'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    app.backendReachable ? Icons.dns : Icons.cloud_off,
                    color: app.backendReachable ? Colors.green : Colors.orange,
                  ),
                  title: const Text('Backend API Reachability'),
                  subtitle: Text(
                    app.backendReachable
                        ? 'Reachable at ${app.api.baseUrl}'
                        : 'Unreachable at ${app.api.baseUrl}',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    isSyncing ? Icons.sync : Icons.schedule,
                    color: isSyncing ? Colors.blue : Colors.grey,
                  ),
                  title: const Text('Automatic Sync Status'),
                  subtitle: Text(
                    isSyncing
                        ? 'Synchronizing queued scans in background...'
                        : (app.queue.lastSyncError.isNotEmpty
                            ? 'Last attempt error: ${app.queue.lastSyncError}'
                            : 'Background poll active (every 30s)'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'How Offline Mode Works',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. Full Resolution Preservation',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'When taking pictures in remote markets, basements, or rural areas without coverage, the high-resolution JPEG is preserved in encrypted local storage.',
                    style: TextStyle(fontSize: 12),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '2. Evidentiary Geotags Stored',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'GPS coordinates (latitude, longitude, altitude) and raid session identifiers are tagged immediately on capture and bundled with the payload.',
                    style: TextStyle(fontSize: 12),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '3. Zero Data Loss Auto-Sync',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'As soon as connection is re-established, the queue sequentially uploads items without interrupting your field inspection workflow.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: (app.queue.length == 0 || isSyncing)
                ? null
                : () => _triggerSync(app),
            icon: isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync),
            label: Text(
              isSyncing ? 'Synchronizing...' : 'Sync Queued Scans Now',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}
