import 'dart:async';
import 'package:flutter/material.dart';
import 'package:triage_client/triage_client.dart';
import '../../telemetry/device_telemetry_manager.dart';

class TelemetryCard extends StatefulWidget {
  final DeviceTelemetryManager telemetryManager;
  final Client serverpodClient;
  final String? deviceId;
  final String? deviceToken;
  final Color cardColor;
  final Color successColor;
  final Color warningColor;
  final Color errorColor;

  const TelemetryCard({
    super.key,
    required this.telemetryManager,
    required this.serverpodClient,
    this.deviceId,
    this.deviceToken,
    required this.cardColor,
    required this.successColor,
    required this.warningColor,
    required this.errorColor,
  });

  @override
  State<TelemetryCard> createState() => _TelemetryCardState();
}

class _TelemetryCardState extends State<TelemetryCard> {
  TelemetrySnapshot? _snapshot;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _statusMessage;
  DeviceTelemetry? _lastSyncedTelemetry;

  @override
  void initState() {
    super.initState();
    _collectSnapshot();
  }

  Future<void> _collectSnapshot() async {
    setState(() => _isLoading = true);
    try {
      final snap = await widget.telemetryManager.collectSnapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = snap;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error collecting telemetry: $e';
      });
    }
  }

  Future<void> _pushTelemetryToServerpod() async {
    final devId = widget.deviceId;
    final token = widget.deviceToken;
    if (devId == null || token == null || token.isEmpty) {
      setState(() {
        _statusMessage = 'Device must be registered before syncing telemetry (See Card 6).';
      });
      return;
    }

    setState(() {
      _isSyncing = true;
      _statusMessage = null;
    });

    try {
      final res = await widget.telemetryManager.syncTelemetry(
        widget.serverpodClient,
        deviceId: devId,
        deviceToken: token,
      );
      if (!mounted) return;
      setState(() {
        _lastSyncedTelemetry = res;
        _statusMessage = 'Telemetry synced to Serverpod at ${res.updatedAt.toLocal().toIso8601String().substring(11, 19)}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Sync error: $e';
      });
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snapshot;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, color: Color(0xFF00CEC9), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '8. Live Device Telemetry Sync (Ticket 09)',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
                onPressed: _isLoading ? null : _collectSnapshot,
                tooltip: 'Refresh Snapshot',
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Streams real-time device health (battery, charging state, volume, brightness, DND) to Serverpod PostgreSQL model and WebSocket subscribers.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),

          // Telemetry Gauges Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: snap == null
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00CEC9)))
                : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildGaugeItem(
                            icon: snap.isCharging ? Icons.battery_charging_full : Icons.battery_std,
                            iconColor: snap.batteryLevel < 20 ? widget.warningColor : widget.successColor,
                            label: 'Battery',
                            value: '${snap.batteryLevel}%',
                            subValue: snap.isCharging ? 'Charging' : 'Discharging',
                          ),
                          _buildGaugeItem(
                            icon: Icons.volume_up,
                            iconColor: const Color(0xFF74B9FF),
                            label: 'Volume',
                            value: '${(snap.volumeLevel * 100).round()}%',
                            subValue: 'System Media',
                          ),
                          _buildGaugeItem(
                            icon: Icons.brightness_6,
                            iconColor: const Color(0xFFFDCB6E),
                            label: 'Brightness',
                            value: '${(snap.brightnessLevel * 100).round()}%',
                            subValue: 'Screen',
                          ),
                          _buildGaugeItem(
                            icon: snap.dndEnabled ? Icons.do_not_disturb_on : Icons.do_not_disturb_off,
                            iconColor: snap.dndEnabled ? widget.warningColor : Colors.white54,
                            label: 'DND',
                            value: snap.dndEnabled ? 'ON' : 'OFF',
                            subValue: 'Interruption',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Snapshot: ${snap.timestamp.toLocal().toIso8601String().substring(11, 19)}',
                            style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
                          ),
                          if (_lastSyncedTelemetry != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: widget.successColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'SERVER SYNCED',
                                style: TextStyle(color: widget.successColor, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),

          // Action Row
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00CEC9),
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: (_isLoading || _isSyncing) ? null : _pushTelemetryToServerpod,
            icon: _isSyncing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                : const Icon(Icons.cloud_upload, size: 18),
            label: Text(
              _isSyncing ? 'Syncing Telemetry...' : 'Sync Telemetry to Serverpod',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),

          if (_statusMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _statusMessage!,
              style: TextStyle(
                color: _statusMessage!.contains('Error') || _statusMessage!.contains('must be')
                    ? widget.warningColor
                    : widget.successColor,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGaugeItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subValue,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text(subValue, style: const TextStyle(color: Colors.white38, fontSize: 9)),
      ],
    );
  }
}
