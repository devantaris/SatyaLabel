import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';

class DiagnosticsSheet extends StatefulWidget {
  const DiagnosticsSheet({super.key});

  @override
  State<DiagnosticsSheet> createState() => _DiagnosticsSheetState();
}

class _DiagnosticsSheetState extends State<DiagnosticsSheet> {
  bool _testingPing = false;
  int? _pingMs;
  LocationPermission? _gpsPermission;
  bool _gpsEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkSensors();
  }

  Future<void> _checkSensors() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      final perm = await Geolocator.checkPermission();
      if (mounted) {
        setState(() {
          _gpsEnabled = enabled;
          _gpsPermission = perm;
        });
      }
    } catch (_) {}
  }

  Future<void> _testPing(AppState app) async {
    setState(() {
      _testingPing = true;
      _pingMs = null;
    });
    final stopwatch = Stopwatch()..start();
    try {
      await app.api.healthCheck();
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _pingMs = stopwatch.elapsedMilliseconds;
        });
      }
    } catch (_) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _pingMs = -1;
        });
      }
    } finally {
      if (mounted) setState(() => _testingPing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('System & Device Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _checkSensors();
              _testPing(app);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Backend Connectivity',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dns),
                  title: const Text('Base Server URL'),
                  subtitle: Text(app.api.baseUrl),
                  trailing: TextButton(
                    onPressed: () => _editBaseUrl(context, app),
                    child: const Text('Edit'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    app.backendReachable ? Icons.check_circle : Icons.error,
                    color: app.backendReachable ? Colors.green : Colors.red,
                  ),
                  title: const Text('Server Ping Latency'),
                  subtitle: Text(
                    _testingPing
                        ? 'Testing latency...'
                        : (_pingMs == null
                            ? (app.backendReachable
                                ? 'Healthy (Tap to ping)'
                                : 'Unreachable')
                            : (_pingMs == -1
                                ? 'Ping timeout or error'
                                : '$_pingMs ms roundtrip')),
                  ),
                  trailing: OutlinedButton(
                    onPressed: _testingPing ? null : () => _testPing(app),
                    child: const Text('Ping'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Evidence Sensors',
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
                    _gpsEnabled ? Icons.gps_fixed : Icons.gps_off,
                    color: _gpsEnabled ? Colors.green : Colors.orange,
                  ),
                  title: const Text('GPS Location Service'),
                  subtitle: Text(
                    _gpsEnabled
                        ? 'Hardware GNSS Active (Ready for Geotagging)'
                        : 'Location Service Disabled in Settings',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('Location Permission'),
                  subtitle: Text(_gpsPermission != null
                      ? _gpsPermission.toString().split('.').last
                      : 'Checking...'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.camera_alt, color: Colors.green),
                  title: Text('High-Resolution OCR Camera'),
                  subtitle: Text('Max Sensor Resolution Preset Enabled'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Inspector Credentials & Security',
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
                    app.isLoggedIn ? Icons.badge : Icons.person_outline,
                    color: app.isLoggedIn ? scheme.primary : Colors.grey,
                  ),
                  title: Text(app.isLoggedIn
                      ? (app.isInspector ? 'Inspector Session' : 'Citizen User')
                      : 'Anonymous Citizen Mode'),
                  subtitle: Text(app.isLoggedIn
                      ? (app.user?.email ?? 'Logged in')
                      : 'Scans stored locally on this device'),
                ),
                if (app.isLoggedIn && app.user?.badgeNumber != null) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.verified_user),
                    title: const Text('Badge Identifier'),
                    subtitle: Text(app.user!.badgeNumber!),
                  ),
                ],
                if (app.isLoggedIn && app.user?.district != null) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.location_city),
                    title: const Text('Assigned District Jurisdiction'),
                    subtitle: Text(app.user!.district!),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Application Build',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('SatyaLabel Framework'),
                  subtitle: Text(
                      'Smart India Hackathon 2026 (SIH26034)\nLegal Metrology (PC) Rules 2011 Compliance Engine'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.storage),
                  title: const Text('Device History Cache'),
                  subtitle: Text('${app.localScanIds.length} scans indexed on this device'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
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
              'Use 10.0.2.2 for the Android emulator. For a physical device '
              'with ADB reverse, use 127.0.0.1 (or your computer\'s LAN IP). '
              'Restart the app after changing.',
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backend URL saved — restart the app to apply'),
          ),
        );
      }
    }
  }
}
