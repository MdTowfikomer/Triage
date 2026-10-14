import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:triage_client/triage_client.dart';
import '../../actions/native_action_client.dart';
import '../../outbox/local_outbox_repository.dart';
import '../../routines/local_routine_scheduler.dart';
import '../../routines/routine_execution_manager.dart';

class LocalRoutineCard extends StatefulWidget {
  final LocalRoutineScheduler scheduler;
  final LocalOutboxRepository repository;
  final NativeActionClient actionClient;
  final Client serverpodClient;
  final String? deviceId;
  final String? deviceToken;
  final Color cardColor;
  final Color successColor;
  final Color warningColor;
  final Color errorColor;

  const LocalRoutineCard({
    super.key,
    required this.scheduler,
    required this.repository,
    required this.actionClient,
    required this.serverpodClient,
    this.deviceId,
    this.deviceToken,
    required this.cardColor,
    required this.successColor,
    required this.warningColor,
    required this.errorColor,
  });

  @override
  State<LocalRoutineCard> createState() => _LocalRoutineCardState();
}

class _LocalRoutineCardState extends State<LocalRoutineCard> {
  bool _canScheduleExactAlarms = false;
  List<LocalRoutineRecord> _mirroredRoutines = [];
  bool _isLoading = false;
  String? _statusMessage;
  RoutineExecutionReport? _lastReport;

  @override
  void initState() {
    super.initState();
    _checkCapabilitiesAndRefresh();
  }

  Future<void> _checkCapabilitiesAndRefresh() async {
    setState(() => _isLoading = true);
    try {
      final canExact = await widget.actionClient.canScheduleExactAlarms();
      final routines = await widget.repository.getLocalRoutines();
      if (!mounted) return;
      setState(() {
        _canScheduleExactAlarms = canExact;
        _mirroredRoutines = routines;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error checking local routines: $e';
      });
    }
  }

  Future<void> _scheduleSampleAlarmRoutine() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final now = DateTime.now().toUtc();
      final scheduledTime = now.add(const Duration(seconds: 10));
      final expiresAt = scheduledTime.add(const Duration(minutes: 5));
      final routineId = 'local-doze-${now.millisecondsSinceEpoch}';
      final occurrenceId = 'occ-doze-${now.millisecondsSinceEpoch}';

      final stepsJson = jsonEncode([
        {'stepId': 's1', 'action': 'set_volume', 'targetValue': 0, 'unattended': true},
        {'stepId': 's2', 'action': 'set_brightness', 'targetValue': 25, 'unattended': true},
        {'stepId': 's3', 'action': 'open_app', 'targetValue': 'camera', 'unattended': false},
      ]);

      await widget.scheduler.mirrorAndScheduleRoutine(
        routineId: routineId,
        occurrenceId: occurrenceId,
        name: 'Doze Night Prep (Exact Alarm)',
        scheduledTime: scheduledTime,
        expiresAt: expiresAt,
        stepsJson: stepsJson,
      );

      await _checkCapabilitiesAndRefresh();
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Exact alarm scheduled for +10s via AlarmManager.setExactAndAllowWhileIdle()';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed to schedule exact alarm: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerExecutionNow(LocalRoutineRecord record) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Executing triggered routine: ${record.name}...';
    });

    try {
      final report = await widget.scheduler.executeTriggeredRoutine(
        occurrenceId: record.occurrenceId,
        routineId: record.routineId,
        name: record.name,
        expiresAt: record.expiresAt,
        stepsJson: record.stepsJson,
        serverpodClient: widget.serverpodClient,
        deviceId: widget.deviceId,
        deviceToken: widget.deviceToken,
      );

      await _checkCapabilitiesAndRefresh();
      if (!mounted) return;
      setState(() {
        _lastReport = report;
        _statusMessage = 'Routine finished: ${report.status} (${report.stepOutcomes.length} steps)';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Execution error: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _testAtomicClaimRace() async {
    if (_mirroredRoutines.isEmpty) {
      setState(() => _statusMessage = 'Schedule a routine first to test atomic claim.');
      return;
    }

    final target = _mirroredRoutines.first;
    setState(() => _statusMessage = 'Simulating race condition on occurrence ${target.occurrenceId}...');

    // Attempt claim #1
    final claim1 = await widget.repository.attemptClaimRoutineOccurrence(target.occurrenceId, target.routineId);
    // Attempt claim #2 (simulating duplicate push)
    final claim2 = await widget.repository.attemptClaimRoutineOccurrence(target.occurrenceId, target.routineId);

    setState(() {
      _statusMessage = 'Atomic Claim Results: Trigger 1 = $claim1, Trigger 2 = $claim2 (Duplicate safely suppressed: ${!claim2})';
    });
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
              const Icon(Icons.alarm_on, color: Color(0xFFE17055), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '9. Local Routine Scheduling & Doze Reconciliation (Ticket 10)',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
                onPressed: _isLoading ? null : _checkCapabilitiesAndRefresh,
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Mirrors scheduled routines to SQLite and registers with Android AlarmManager.setExactAndAllowWhileIdle() to wake device from Doze. Reconciles via atomic SQLite claims.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),

          // AlarmManager Capability Badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Icon(
                  _canScheduleExactAlarms ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: _canScheduleExactAlarms ? widget.successColor : widget.warningColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _canScheduleExactAlarms
                      ? 'AlarmManager Exact Alarms (SCHEDULE_EXACT_ALARM): GRANTED'
                      : 'Exact Alarm permission needed for Doze execution',
                    style: TextStyle(
                      color: _canScheduleExactAlarms ? widget.successColor : widget.warningColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!_canScheduleExactAlarms)
                  TextButton(
                    onPressed: () => widget.actionClient.openExactAlarmSettings(),
                    child: const Text('Open Settings', style: TextStyle(color: Color(0xFF74B9FF), fontSize: 11)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE17055),
                  foregroundColor: Colors.white,
                ),
                onPressed: _isLoading ? null : _scheduleSampleAlarmRoutine,
                icon: const Icon(Icons.add_alarm, size: 16),
                label: const Text('Schedule Exact Alarm (+10s)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D3436),
                  foregroundColor: Colors.white,
                ),
                onPressed: _isLoading || _mirroredRoutines.isEmpty
                    ? null
                    : () => _triggerExecutionNow(_mirroredRoutines.first),
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('Trigger Latest Routine', style: TextStyle(fontSize: 12)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF74B9FF)),
                  foregroundColor: const Color(0xFF74B9FF),
                ),
                onPressed: _isLoading ? null : _testAtomicClaimRace,
                icon: const Icon(Icons.sync_problem, size: 16),
                label: const Text('Test Atomic Claim (Race)', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),

          if (_statusMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                _statusMessage!,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ],

          if (_lastReport != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _lastReport!.status == 'completed'
                      ? widget.successColor.withValues(alpha: 0.6)
                      : widget.warningColor.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXECUTION RESULT: ${_lastReport!.status.toUpperCase()}',
                    style: TextStyle(
                      color: _lastReport!.status == 'completed' ? widget.successColor : widget.warningColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final step in _lastReport!.stepOutcomes) ...[
                    Row(
                      children: [
                        Icon(
                          step.status == 'success' || step.status == 'handed_off' ? Icons.check_circle : Icons.error,
                          size: 14,
                          color: step.status == 'success' || step.status == 'handed_off' ? widget.successColor : widget.errorColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${step.action} [${step.stepId}]: status=${step.status} (${step.latencyMs}ms)',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          Text(
            'Mirrored Local SQLite Routines (${_mirroredRoutines.length}):',
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          if (_mirroredRoutines.isEmpty)
            const Text('No mirrored routines in SQLite.', style: TextStyle(color: Colors.white38, fontSize: 11))
          else
            Column(
              children: [
                for (final r in _mirroredRoutines.take(5)) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('Scheduled: ${r.scheduledTime.toLocal().toIso8601String().substring(11, 19)} | Status: ${r.status}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 10)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: r.status == 'completed'
                                ? widget.successColor.withValues(alpha: 0.2)
                                : widget.warningColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            r.status.toUpperCase(),
                            style: TextStyle(
                              color: r.status == 'completed' ? widget.successColor : widget.warningColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
