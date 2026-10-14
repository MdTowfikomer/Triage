import 'package:flutter/material.dart';
import 'package:triage_client/triage_client.dart';
import '../../demo/hackathon_demo_harness.dart';

class HackathonDemoCard extends StatefulWidget {
  final HackathonDemoHarness harness;
  final Client serverpodClient;
  final String? deviceId;
  final String? deviceToken;
  final Color cardColor;
  final Color successColor;
  final Color warningColor;
  final Color errorColor;

  const HackathonDemoCard({
    super.key,
    required this.harness,
    required this.serverpodClient,
    this.deviceId,
    this.deviceToken,
    required this.cardColor,
    required this.successColor,
    required this.warningColor,
    required this.errorColor,
  });

  @override
  State<HackathonDemoCard> createState() => _HackathonDemoCardState();
}

class _HackathonDemoCardState extends State<HackathonDemoCard> {
  bool _isRunning = false;
  List<DemoSceneResult> _sceneResults = [];
  String? _currentRunningScene;

  Future<void> _runAllScenes() async {
    setState(() {
      _isRunning = true;
      _sceneResults = [];
      _currentRunningScene = 'Initializing 4-Scene Test Run...';
    });

    final results = <DemoSceneResult>[];

    try {
      // Scene 1
      setState(() => _currentRunningScene = 'Running Scene 1: Airplane Mode Offline Commands...');
      final s1 = await widget.harness.runScene1OfflineCommands();
      results.add(s1);
      setState(() => _sceneResults = List.from(results));

      // Scene 2
      setState(() => _currentRunningScene = 'Running Scene 2: Reconnect & Deduplicated Sync...');
      final s2 = await widget.harness.runScene2ReconnectAndSync(
        serverpodClient: widget.serverpodClient,
        deviceId: widget.deviceId,
        deviceToken: widget.deviceToken,
      );
      results.add(s2);
      setState(() => _sceneResults = List.from(results));

      // Scene 3
      setState(() => _currentRunningScene = 'Running Scene 3: Scheduled Routine & ACK...');
      final s3 = await widget.harness.runScene3ScheduledRoutine(
        serverpodClient: widget.serverpodClient,
        deviceId: widget.deviceId,
        deviceToken: widget.deviceToken,
      );
      results.add(s3);
      setState(() => _sceneResults = List.from(results));

      // Scene 4
      setState(() => _currentRunningScene = 'Running Scene 4: BYOK Conversational Interaction & Firewall...');
      final s4 = await widget.harness.runScene4ByokInteraction();
      results.add(s4);
      setState(() => _sceneResults = List.from(results));

      setState(() {
        _currentRunningScene = 'All 4 Scenes Completed!';
      });
    } catch (e) {
      setState(() {
        _currentRunningScene = 'Harness encountered error: $e';
      });
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  Future<void> _runSingleScene(int sceneNum) async {
    setState(() {
      _isRunning = true;
      _currentRunningScene = 'Running Scene $sceneNum...';
    });

    try {
      DemoSceneResult res;
      switch (sceneNum) {
        case 1:
          res = await widget.harness.runScene1OfflineCommands();
          break;
        case 2:
          res = await widget.harness.runScene2ReconnectAndSync(
            serverpodClient: widget.serverpodClient,
            deviceId: widget.deviceId,
            deviceToken: widget.deviceToken,
          );
          break;
        case 3:
          res = await widget.harness.runScene3ScheduledRoutine(
            serverpodClient: widget.serverpodClient,
            deviceId: widget.deviceId,
            deviceToken: widget.deviceToken,
          );
          break;
        case 4:
          res = await widget.harness.runScene4ByokInteraction();
          break;
        default:
          return;
      }

      final existingIndex = _sceneResults.indexWhere((r) => r.sceneNumber == sceneNum);
      if (existingIndex >= 0) {
        _sceneResults[existingIndex] = res;
      } else {
        _sceneResults.add(res);
        _sceneResults.sort((a, b) => a.sceneNumber.compareTo(b.sceneNumber));
      }

      setState(() {
        _currentRunningScene = 'Scene $sceneNum Finished: ${res.status.name.toUpperCase()}';
      });
    } catch (e) {
      setState(() {
        _currentRunningScene = 'Scene $sceneNum Error: $e';
      });
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.verified, color: Color(0xFF00B894), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '11. Core 4-Scene Hackathon Demo Verification (Ticket 07)',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              if (_isRunning)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00B894))),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'One-click automated verification of all 4 hackathon proof-points: (1) Airplane mode offline commands, (2) Reconnect & outbox sync, (3) Scheduled routine with client ACK, and (4) BYOK frontier LLM streaming.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),

          // Primary Run All Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B894),
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _isRunning ? null : _runAllScenes,
            icon: const Icon(Icons.play_circle_fill, size: 20),
            label: Text(
              _isRunning ? 'Executing Automated Verification...' : 'Run All 4 Demo Scenes End-to-End',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),

          // Individual scene quick-launch chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ActionChip(
                backgroundColor: Colors.white10,
                label: const Text('Scene 1: Offline', style: TextStyle(color: Colors.white, fontSize: 11)),
                onPressed: _isRunning ? null : () => _runSingleScene(1),
              ),
              ActionChip(
                backgroundColor: Colors.white10,
                label: const Text('Scene 2: Reconnect', style: TextStyle(color: Colors.white, fontSize: 11)),
                onPressed: _isRunning ? null : () => _runSingleScene(2),
              ),
              ActionChip(
                backgroundColor: Colors.white10,
                label: const Text('Scene 3: Routine', style: TextStyle(color: Colors.white, fontSize: 11)),
                onPressed: _isRunning ? null : () => _runSingleScene(3),
              ),
              ActionChip(
                backgroundColor: Colors.white10,
                label: const Text('Scene 4: BYOK', style: TextStyle(color: Colors.white, fontSize: 11)),
                onPressed: _isRunning ? null : () => _runSingleScene(4),
              ),
            ],
          ),

          if (_currentRunningScene != null) ...[
            const SizedBox(height: 8),
            Text(
              _currentRunningScene!,
              style: const TextStyle(color: Color(0xFF74B9FF), fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 12),

          // Scenes Results List
          if (_sceneResults.isEmpty)
            const Text('Tap "Run All" or individual scene chips to execute verification.',
                style: TextStyle(color: Colors.white38, fontSize: 11))
          else
            Column(
              children: [
                for (final r in _sceneResults) ...[
                  _buildSceneRow(r),
                  const SizedBox(height: 8),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSceneRow(DemoSceneResult result) {
    Color statusColor;
    IconData icon;
    switch (result.status) {
      case DemoSceneStatus.passed:
        statusColor = widget.successColor;
        icon = Icons.check_circle;
        break;
      case DemoSceneStatus.failed:
        statusColor = widget.errorColor;
        icon = Icons.error;
        break;
      case DemoSceneStatus.running:
        statusColor = const Color(0xFF74B9FF);
        icon = Icons.hourglass_top;
        break;
      default:
        statusColor = Colors.white54;
        icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: statusColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Scene ${result.sceneNumber}: ${result.title}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  result.status.name.toUpperCase(),
                  style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(result.summary, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          if (result.error != null) ...[
            const SizedBox(height: 4),
            Text('Error: ${result.error}', style: TextStyle(color: widget.errorColor, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
          if (result.metrics.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: result.metrics.entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${entry.key}: ${entry.value}',
                    style: const TextStyle(color: Color(0xFF74B9FF), fontSize: 10, fontFamily: 'monospace'),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
