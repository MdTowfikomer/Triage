/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_type_check

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _iacc;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _iaic;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'package:triage_client/src/protocol/inbox_item.dart' as _iadxe3ww;
import 'device_registration.dart' as _ihub5uuq;
import 'device_registration_response.dart' as _ii7e5rit;
import 'device_telemetry.dart' as _iucxouii;
import 'inbox_event.dart' as _icfpv71d;
import 'inbox_item.dart' as _iv6iq8qv;
import 'recording.dart' as _ih2awd28;
import 'reminder.dart' as _ic7cmrsw;
import 'routine_acknowledgement_event.dart' as _i2bxt07m;
import 'routine_dispatch_event.dart' as _i4ml9vrj;
import 'routine_schedule.dart' as _iw0r1gfy;
import 'routine_schedule_response.dart' as _itjmdh3b;
import 'routine_step_outcome.dart' as _iztwdzxw;
import 'triage_exception.dart' as _i6yvegu7;
import 'voice_action.dart' as _it6n72xo;
import 'voice_command_log.dart' as _ivj8g45v;
import 'voice_command_sync_batch.dart' as _im75y1ic;
import 'voice_command_sync_entry.dart' as _is11prk2;
import 'voice_command_sync_result.dart' as _i5z3bmka;
export 'device_registration.dart';
export 'device_registration_response.dart';
export 'device_telemetry.dart';
export 'inbox_event.dart';
export 'inbox_item.dart';
export 'recording.dart';
export 'reminder.dart';
export 'routine_acknowledgement_event.dart';
export 'routine_dispatch_event.dart';
export 'routine_schedule.dart';
export 'routine_schedule_response.dart';
export 'routine_step_outcome.dart';
export 'triage_exception.dart';
export 'voice_action.dart';
export 'voice_command_log.dart';
export 'voice_command_sync_batch.dart';
export 'voice_command_sync_entry.dart';
export 'voice_command_sync_result.dart';
export 'client.dart';

class Protocol extends _isc.SerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._().._registerHostProtocols();

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on _isc.DeserializationClassNameNotFoundException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _ihub5uuq.DeviceRegistration) {
      return _ihub5uuq.DeviceRegistration.fromJson(data) as T;
    }
    if (t == _ii7e5rit.DeviceRegistrationResponse) {
      return _ii7e5rit.DeviceRegistrationResponse.fromJson(data) as T;
    }
    if (t == _iucxouii.DeviceTelemetry) {
      return _iucxouii.DeviceTelemetry.fromJson(data) as T;
    }
    if (t == _icfpv71d.InboxEvent) {
      return _icfpv71d.InboxEvent.fromJson(data) as T;
    }
    if (t == _iv6iq8qv.InboxItem) {
      return _iv6iq8qv.InboxItem.fromJson(data) as T;
    }
    if (t == _ih2awd28.Recording) {
      return _ih2awd28.Recording.fromJson(data) as T;
    }
    if (t == _ic7cmrsw.Reminder) {
      return _ic7cmrsw.Reminder.fromJson(data) as T;
    }
    if (t == _i2bxt07m.RoutineAcknowledgementEvent) {
      return _i2bxt07m.RoutineAcknowledgementEvent.fromJson(data) as T;
    }
    if (t == _i4ml9vrj.RoutineDispatchEvent) {
      return _i4ml9vrj.RoutineDispatchEvent.fromJson(data) as T;
    }
    if (t == _iw0r1gfy.RoutineSchedule) {
      return _iw0r1gfy.RoutineSchedule.fromJson(data) as T;
    }
    if (t == _itjmdh3b.RoutineScheduleResponse) {
      return _itjmdh3b.RoutineScheduleResponse.fromJson(data) as T;
    }
    if (t == _iztwdzxw.RoutineStepOutcome) {
      return _iztwdzxw.RoutineStepOutcome.fromJson(data) as T;
    }
    if (t == _i6yvegu7.TriageException) {
      return _i6yvegu7.TriageException.fromJson(data) as T;
    }
    if (t == _it6n72xo.VoiceActionResult) {
      return _it6n72xo.VoiceActionResult.fromJson(data) as T;
    }
    if (t == _ivj8g45v.VoiceCommandLog) {
      return _ivj8g45v.VoiceCommandLog.fromJson(data) as T;
    }
    if (t == _im75y1ic.VoiceCommandSyncBatch) {
      return _im75y1ic.VoiceCommandSyncBatch.fromJson(data) as T;
    }
    if (t == _is11prk2.VoiceCommandSyncEntry) {
      return _is11prk2.VoiceCommandSyncEntry.fromJson(data) as T;
    }
    if (t == _i5z3bmka.VoiceCommandSyncResult) {
      return _i5z3bmka.VoiceCommandSyncResult.fromJson(data) as T;
    }
    if (t == _isc.getType<_ihub5uuq.DeviceRegistration?>()) {
      return (data != null ? _ihub5uuq.DeviceRegistration.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ii7e5rit.DeviceRegistrationResponse?>()) {
      return (data != null
              ? _ii7e5rit.DeviceRegistrationResponse.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_iucxouii.DeviceTelemetry?>()) {
      return (data != null ? _iucxouii.DeviceTelemetry.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_icfpv71d.InboxEvent?>()) {
      return (data != null ? _icfpv71d.InboxEvent.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_iv6iq8qv.InboxItem?>()) {
      return (data != null ? _iv6iq8qv.InboxItem.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_ih2awd28.Recording?>()) {
      return (data != null ? _ih2awd28.Recording.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_ic7cmrsw.Reminder?>()) {
      return (data != null ? _ic7cmrsw.Reminder.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_i2bxt07m.RoutineAcknowledgementEvent?>()) {
      return (data != null
              ? _i2bxt07m.RoutineAcknowledgementEvent.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_i4ml9vrj.RoutineDispatchEvent?>()) {
      return (data != null
              ? _i4ml9vrj.RoutineDispatchEvent.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_iw0r1gfy.RoutineSchedule?>()) {
      return (data != null ? _iw0r1gfy.RoutineSchedule.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_itjmdh3b.RoutineScheduleResponse?>()) {
      return (data != null
              ? _itjmdh3b.RoutineScheduleResponse.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_iztwdzxw.RoutineStepOutcome?>()) {
      return (data != null ? _iztwdzxw.RoutineStepOutcome.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_i6yvegu7.TriageException?>()) {
      return (data != null ? _i6yvegu7.TriageException.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_it6n72xo.VoiceActionResult?>()) {
      return (data != null ? _it6n72xo.VoiceActionResult.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ivj8g45v.VoiceCommandLog?>()) {
      return (data != null ? _ivj8g45v.VoiceCommandLog.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_im75y1ic.VoiceCommandSyncBatch?>()) {
      return (data != null
              ? _im75y1ic.VoiceCommandSyncBatch.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_is11prk2.VoiceCommandSyncEntry?>()) {
      return (data != null
              ? _is11prk2.VoiceCommandSyncEntry.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_i5z3bmka.VoiceCommandSyncResult?>()) {
      return (data != null
              ? _i5z3bmka.VoiceCommandSyncResult.fromJson(data)
              : null)
          as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == _isc.getType<List<String>?>()) {
      return (data != null
              ? (data as List).map((e) => deserialize<String>(e)).toList()
              : null)
          as T;
    }
    if (t == List<_iztwdzxw.RoutineStepOutcome>) {
      return (data as List)
              .map((e) => deserialize<_iztwdzxw.RoutineStepOutcome>(e))
              .toList()
          as T;
    }
    if (t == List<_is11prk2.VoiceCommandSyncEntry>) {
      return (data as List)
              .map((e) => deserialize<_is11prk2.VoiceCommandSyncEntry>(e))
              .toList()
          as T;
    }
    if (t == List<_iadxe3ww.InboxItem>) {
      return (data as List)
              .map((e) => deserialize<_iadxe3ww.InboxItem>(e))
              .toList()
          as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == _isc.getType<List<String>?>()) {
      return (data != null
              ? (data as List).map((e) => deserialize<String>(e)).toList()
              : null)
          as T;
    }
    try {
      return _iaic.Protocol().deserialize<T>(data, t);
    } on _isc.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _iacc.Protocol().deserialize<T>(data, t);
    } on _isc.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _ihub5uuq.DeviceRegistration => 'DeviceRegistration',
      _ii7e5rit.DeviceRegistrationResponse => 'DeviceRegistrationResponse',
      _iucxouii.DeviceTelemetry => 'DeviceTelemetry',
      _icfpv71d.InboxEvent => 'InboxEvent',
      _iv6iq8qv.InboxItem => 'InboxItem',
      _ih2awd28.Recording => 'Recording',
      _ic7cmrsw.Reminder => 'Reminder',
      _i2bxt07m.RoutineAcknowledgementEvent => 'RoutineAcknowledgementEvent',
      _i4ml9vrj.RoutineDispatchEvent => 'RoutineDispatchEvent',
      _iw0r1gfy.RoutineSchedule => 'RoutineSchedule',
      _itjmdh3b.RoutineScheduleResponse => 'RoutineScheduleResponse',
      _iztwdzxw.RoutineStepOutcome => 'RoutineStepOutcome',
      _i6yvegu7.TriageException => 'TriageException',
      _it6n72xo.VoiceActionResult => 'VoiceActionResult',
      _ivj8g45v.VoiceCommandLog => 'VoiceCommandLog',
      _im75y1ic.VoiceCommandSyncBatch => 'VoiceCommandSyncBatch',
      _is11prk2.VoiceCommandSyncEntry => 'VoiceCommandSyncEntry',
      _i5z3bmka.VoiceCommandSyncResult => 'VoiceCommandSyncResult',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst('triage.', '');
    }

    switch (data) {
      case _ihub5uuq.DeviceRegistration():
        return 'DeviceRegistration';
      case _ii7e5rit.DeviceRegistrationResponse():
        return 'DeviceRegistrationResponse';
      case _iucxouii.DeviceTelemetry():
        return 'DeviceTelemetry';
      case _icfpv71d.InboxEvent():
        return 'InboxEvent';
      case _iv6iq8qv.InboxItem():
        return 'InboxItem';
      case _ih2awd28.Recording():
        return 'Recording';
      case _ic7cmrsw.Reminder():
        return 'Reminder';
      case _i2bxt07m.RoutineAcknowledgementEvent():
        return 'RoutineAcknowledgementEvent';
      case _i4ml9vrj.RoutineDispatchEvent():
        return 'RoutineDispatchEvent';
      case _iw0r1gfy.RoutineSchedule():
        return 'RoutineSchedule';
      case _itjmdh3b.RoutineScheduleResponse():
        return 'RoutineScheduleResponse';
      case _iztwdzxw.RoutineStepOutcome():
        return 'RoutineStepOutcome';
      case _i6yvegu7.TriageException():
        return 'TriageException';
      case _it6n72xo.VoiceActionResult():
        return 'VoiceActionResult';
      case _ivj8g45v.VoiceCommandLog():
        return 'VoiceCommandLog';
      case _im75y1ic.VoiceCommandSyncBatch():
        return 'VoiceCommandSyncBatch';
      case _is11prk2.VoiceCommandSyncEntry():
        return 'VoiceCommandSyncEntry';
      case _i5z3bmka.VoiceCommandSyncResult():
        return 'VoiceCommandSyncResult';
    }
    className = _iaic.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_idp.$className';
    }
    className = _iacc.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_core.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'DeviceRegistration') {
      return deserialize<_ihub5uuq.DeviceRegistration>(data['data']);
    }
    if (dataClassName == 'DeviceRegistrationResponse') {
      return deserialize<_ii7e5rit.DeviceRegistrationResponse>(data['data']);
    }
    if (dataClassName == 'DeviceTelemetry') {
      return deserialize<_iucxouii.DeviceTelemetry>(data['data']);
    }
    if (dataClassName == 'InboxEvent') {
      return deserialize<_icfpv71d.InboxEvent>(data['data']);
    }
    if (dataClassName == 'InboxItem') {
      return deserialize<_iv6iq8qv.InboxItem>(data['data']);
    }
    if (dataClassName == 'Recording') {
      return deserialize<_ih2awd28.Recording>(data['data']);
    }
    if (dataClassName == 'Reminder') {
      return deserialize<_ic7cmrsw.Reminder>(data['data']);
    }
    if (dataClassName == 'RoutineAcknowledgementEvent') {
      return deserialize<_i2bxt07m.RoutineAcknowledgementEvent>(data['data']);
    }
    if (dataClassName == 'RoutineDispatchEvent') {
      return deserialize<_i4ml9vrj.RoutineDispatchEvent>(data['data']);
    }
    if (dataClassName == 'RoutineSchedule') {
      return deserialize<_iw0r1gfy.RoutineSchedule>(data['data']);
    }
    if (dataClassName == 'RoutineScheduleResponse') {
      return deserialize<_itjmdh3b.RoutineScheduleResponse>(data['data']);
    }
    if (dataClassName == 'RoutineStepOutcome') {
      return deserialize<_iztwdzxw.RoutineStepOutcome>(data['data']);
    }
    if (dataClassName == 'TriageException') {
      return deserialize<_i6yvegu7.TriageException>(data['data']);
    }
    if (dataClassName == 'VoiceActionResult') {
      return deserialize<_it6n72xo.VoiceActionResult>(data['data']);
    }
    if (dataClassName == 'VoiceCommandLog') {
      return deserialize<_ivj8g45v.VoiceCommandLog>(data['data']);
    }
    if (dataClassName == 'VoiceCommandSyncBatch') {
      return deserialize<_im75y1ic.VoiceCommandSyncBatch>(data['data']);
    }
    if (dataClassName == 'VoiceCommandSyncEntry') {
      return deserialize<_is11prk2.VoiceCommandSyncEntry>(data['data']);
    }
    if (dataClassName == 'VoiceCommandSyncResult') {
      return deserialize<_i5z3bmka.VoiceCommandSyncResult>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_auth_idp.')) {
      data['className'] = dataClassName.substring(19);
      return _iaic.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _iacc.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  void _registerHostProtocols() {
    _iaic.Protocol().registerHostProtocol('triage', this);
    _iacc.Protocol().registerHostProtocol('triage', this);
  }

  @override
  String getModuleName() => 'triage';

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _iaic.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _iacc.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
