/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _is;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _iacs;
import 'package:serverpod_auth_idp_server/serverpod_auth_idp_server.dart'
    as _iais;
import 'package:triage_server/src/generated/device_telemetry.dart' as _i375h7rk;
import 'package:triage_server/src/generated/future_calls.dart' as _i2j7jym1;
import 'package:triage_server/src/generated/inbox_item.dart' as _iaro1wa7;
import 'package:triage_server/src/generated/routine_acknowledgement_event.dart'
    as _izmj5tvz;
import 'package:triage_server/src/generated/voice_command_sync_batch.dart'
    as _i7hgt9s1;
import '../auth/email_idp_endpoint.dart' as _iuc1hd5t;
import '../auth/jwt_refresh_endpoint.dart' as _inwq3ztq;
import '../endpoints/command_sync_endpoint.dart' as _ii7zkoeo;
import '../endpoints/dev_auth_endpoint.dart' as _icypl9i6;
import '../endpoints/device_endpoint.dart' as _ipl99gaq;
import '../endpoints/inbox_endpoint.dart' as _ib2xr017;
import '../endpoints/routine_endpoint.dart' as _ihcuaodq;
import '../endpoints/sync_endpoint.dart' as _i609im4b;
import '../endpoints/telemetry_endpoint.dart' as _i34lh6ht;
import '../endpoints/voice_endpoint.dart' as _iq0gswfc;
export 'future_calls.dart' show ServerpodFutureCallsGetter;

class Endpoints extends _is.EndpointDispatch {
  @override
  void initializeEndpoints(_is.Server server) {
    var endpoints = <String, _is.Endpoint>{
      'emailIdp': _iuc1hd5t.EmailIdpEndpoint()
        ..initialize(
          server,
          'emailIdp',
          null,
        ),
      'jwtRefresh': _inwq3ztq.JwtRefreshEndpoint()
        ..initialize(
          server,
          'jwtRefresh',
          null,
        ),
      'commandSync': _ii7zkoeo.CommandSyncEndpoint()
        ..initialize(
          server,
          'commandSync',
          null,
        ),
      'devAuth': _icypl9i6.DevAuthEndpoint()
        ..initialize(
          server,
          'devAuth',
          null,
        ),
      'device': _ipl99gaq.DeviceEndpoint()
        ..initialize(
          server,
          'device',
          null,
        ),
      'inbox': _ib2xr017.InboxEndpoint()
        ..initialize(
          server,
          'inbox',
          null,
        ),
      'routine': _ihcuaodq.RoutineEndpoint()
        ..initialize(
          server,
          'routine',
          null,
        ),
      'sync': _i609im4b.SyncEndpoint()
        ..initialize(
          server,
          'sync',
          null,
        ),
      'telemetry': _i34lh6ht.TelemetryEndpoint()
        ..initialize(
          server,
          'telemetry',
          null,
        ),
      'voice': _iq0gswfc.VoiceEndpoint()
        ..initialize(
          server,
          'voice',
          null,
        ),
    };
    connectors['emailIdp'] = _is.EndpointConnector(
      name: 'emailIdp',
      endpoint: endpoints['emailIdp']!,
      methodConnectors: {
        'login': _is.MethodConnector(
          name: 'login',
          params: {
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'password': _is.ParameterDescription(
              name: 'password',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint).login(
                    session,
                    email: params['email'],
                    password: params['password'],
                  ),
        ),
        'startRegistration': _is.MethodConnector(
          name: 'startRegistration',
          params: {
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .startRegistration(
                    session,
                    email: params['email'],
                  ),
        ),
        'verifyRegistrationCode': _is.MethodConnector(
          name: 'verifyRegistrationCode',
          params: {
            'accountRequestId': _is.ParameterDescription(
              name: 'accountRequestId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'verificationCode': _is.ParameterDescription(
              name: 'verificationCode',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .verifyRegistrationCode(
                    session,
                    accountRequestId: params['accountRequestId'],
                    verificationCode: params['verificationCode'],
                  ),
        ),
        'finishRegistration': _is.MethodConnector(
          name: 'finishRegistration',
          params: {
            'registrationToken': _is.ParameterDescription(
              name: 'registrationToken',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'password': _is.ParameterDescription(
              name: 'password',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .finishRegistration(
                    session,
                    registrationToken: params['registrationToken'],
                    password: params['password'],
                  ),
        ),
        'startPasswordReset': _is.MethodConnector(
          name: 'startPasswordReset',
          params: {
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .startPasswordReset(
                    session,
                    email: params['email'],
                  ),
        ),
        'verifyPasswordResetCode': _is.MethodConnector(
          name: 'verifyPasswordResetCode',
          params: {
            'passwordResetRequestId': _is.ParameterDescription(
              name: 'passwordResetRequestId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'verificationCode': _is.ParameterDescription(
              name: 'verificationCode',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .verifyPasswordResetCode(
                    session,
                    passwordResetRequestId: params['passwordResetRequestId'],
                    verificationCode: params['verificationCode'],
                  ),
        ),
        'finishPasswordReset': _is.MethodConnector(
          name: 'finishPasswordReset',
          params: {
            'finishPasswordResetToken': _is.ParameterDescription(
              name: 'finishPasswordResetToken',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'newPassword': _is.ParameterDescription(
              name: 'newPassword',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .finishPasswordReset(
                    session,
                    finishPasswordResetToken:
                        params['finishPasswordResetToken'],
                    newPassword: params['newPassword'],
                  ),
        ),
        'hasAccount': _is.MethodConnector(
          name: 'hasAccount',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .hasAccount(session),
        ),
      },
    );
    connectors['jwtRefresh'] = _is.EndpointConnector(
      name: 'jwtRefresh',
      endpoint: endpoints['jwtRefresh']!,
      methodConnectors: {
        'refreshAccessToken': _is.MethodConnector(
          name: 'refreshAccessToken',
          params: {
            'refreshToken': _is.ParameterDescription(
              name: 'refreshToken',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['jwtRefresh'] as _inwq3ztq.JwtRefreshEndpoint)
                      .refreshAccessToken(
                        session,
                        refreshToken: params['refreshToken'],
                      ),
        ),
      },
    );
    connectors['commandSync'] = _is.EndpointConnector(
      name: 'commandSync',
      endpoint: endpoints['commandSync']!,
      methodConnectors: {
        'syncBatch': _is.MethodConnector(
          name: 'syncBatch',
          params: {
            'batch': _is.ParameterDescription(
              name: 'batch',
              type: _is.getType<_i7hgt9s1.VoiceCommandSyncBatch>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['commandSync'] as _ii7zkoeo.CommandSyncEndpoint)
                      .syncBatch(
                        session,
                        params['batch'],
                      ),
        ),
      },
    );
    connectors['devAuth'] = _is.EndpointConnector(
      name: 'devAuth',
      endpoint: endpoints['devAuth']!,
      methodConnectors: {
        'authenticatePilotUser': _is.MethodConnector(
          name: 'authenticatePilotUser',
          params: {
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['devAuth'] as _icypl9i6.DevAuthEndpoint)
                  .authenticatePilotUser(
                    session,
                    email: params['email'],
                  ),
        ),
      },
    );
    connectors['device'] = _is.EndpointConnector(
      name: 'device',
      endpoint: endpoints['device']!,
      methodConnectors: {
        'registerDevice': _is.MethodConnector(
          name: 'registerDevice',
          params: {
            'deviceId': _is.ParameterDescription(
              name: 'deviceId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'deviceName': _is.ParameterDescription(
              name: 'deviceName',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['device'] as _ipl99gaq.DeviceEndpoint)
                  .registerDevice(
                    session,
                    params['deviceId'],
                    deviceName: params['deviceName'],
                  ),
        ),
      },
    );
    connectors['inbox'] = _is.EndpointConnector(
      name: 'inbox',
      endpoint: endpoints['inbox']!,
      methodConnectors: {
        'createItem': _is.MethodConnector(
          name: 'createItem',
          params: {
            'item': _is.ParameterDescription(
              name: 'item',
              type: _is.getType<_iaro1wa7.InboxItem>(),
              nullable: false,
            ),
            'allowRecording': _is.ParameterDescription(
              name: 'allowRecording',
              type: _is.getType<bool?>(),
              nullable: true,
            ),
            'expectedUserId': _is.ParameterDescription(
              name: 'expectedUserId',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['inbox'] as _ib2xr017.InboxEndpoint).createItem(
                    session,
                    params['item'],
                    allowRecording: params['allowRecording'],
                    expectedUserId: params['expectedUserId'],
                  ),
        ),
        'listItems': _is.MethodConnector(
          name: 'listItems',
          params: {
            'type': _is.ParameterDescription(
              name: 'type',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'limit': _is.ParameterDescription(
              name: 'limit',
              type: _is.getType<int?>(),
              nullable: true,
            ),
            'offset': _is.ParameterDescription(
              name: 'offset',
              type: _is.getType<int?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['inbox'] as _ib2xr017.InboxEndpoint).listItems(
                    session,
                    type: params['type'],
                    limit: params['limit'],
                    offset: params['offset'],
                  ),
        ),
        'completeItem': _is.MethodConnector(
          name: 'completeItem',
          params: {
            'itemId': _is.ParameterDescription(
              name: 'itemId',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['inbox'] as _ib2xr017.InboxEndpoint).completeItem(
                    session,
                    params['itemId'],
                  ),
        ),
        'updateItem': _is.MethodConnector(
          name: 'updateItem',
          params: {
            'itemId': _is.ParameterDescription(
              name: 'itemId',
              type: _is.getType<int>(),
              nullable: false,
            ),
            'title': _is.ParameterDescription(
              name: 'title',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'body': _is.ParameterDescription(
              name: 'body',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'priority': _is.ParameterDescription(
              name: 'priority',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'dueDate': _is.ParameterDescription(
              name: 'dueDate',
              type: _is.getType<DateTime?>(),
              nullable: true,
            ),
            'tags': _is.ParameterDescription(
              name: 'tags',
              type: _is.getType<List<String>?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['inbox'] as _ib2xr017.InboxEndpoint).updateItem(
                    session,
                    params['itemId'],
                    params['title'],
                    params['body'],
                    params['priority'],
                    params['dueDate'],
                    params['tags'],
                  ),
        ),
        'deleteItem': _is.MethodConnector(
          name: 'deleteItem',
          params: {
            'itemId': _is.ParameterDescription(
              name: 'itemId',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['inbox'] as _ib2xr017.InboxEndpoint).deleteItem(
                    session,
                    params['itemId'],
                  ),
        ),
      },
    );
    connectors['routine'] = _is.EndpointConnector(
      name: 'routine',
      endpoint: endpoints['routine']!,
      methodConnectors: {
        'scheduleRoutine': _is.MethodConnector(
          name: 'scheduleRoutine',
          params: {
            'deviceId': _is.ParameterDescription(
              name: 'deviceId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'scheduledTime': _is.ParameterDescription(
              name: 'scheduledTime',
              type: _is.getType<DateTime>(),
              nullable: false,
            ),
            'stepsJson': _is.ParameterDescription(
              name: 'stepsJson',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['routine'] as _ihcuaodq.RoutineEndpoint)
                  .scheduleRoutine(
                    session,
                    deviceId: params['deviceId'],
                    name: params['name'],
                    scheduledTime: params['scheduledTime'],
                    stepsJson: params['stepsJson'],
                  ),
        ),
        'acknowledgeRoutine': _is.MethodConnector(
          name: 'acknowledgeRoutine',
          params: {
            'ack': _is.ParameterDescription(
              name: 'ack',
              type: _is.getType<_izmj5tvz.RoutineAcknowledgementEvent>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['routine'] as _ihcuaodq.RoutineEndpoint)
                  .acknowledgeRoutine(
                    session,
                    params['ack'],
                  ),
        ),
        'getRoutine': _is.MethodConnector(
          name: 'getRoutine',
          params: {
            'routineId': _is.ParameterDescription(
              name: 'routineId',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['routine'] as _ihcuaodq.RoutineEndpoint)
                  .getRoutine(
                    session,
                    params['routineId'],
                  ),
        ),
        'streamRoutineDispatches': _is.MethodStreamConnector(
          name: 'streamRoutineDispatches',
          params: {
            'deviceId': _is.ParameterDescription(
              name: 'deviceId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'deviceToken': _is.ParameterDescription(
              name: 'deviceToken',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          streamParams: {},
          returnType: _is.MethodStreamReturnType.streamType,
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['routine'] as _ihcuaodq.RoutineEndpoint)
                  .streamRoutineDispatches(
                    session,
                    deviceId: params['deviceId'],
                    deviceToken: params['deviceToken'],
                  ),
        ),
      },
    );
    connectors['sync'] = _is.EndpointConnector(
      name: 'sync',
      endpoint: endpoints['sync']!,
      methodConnectors: {
        'streamInbox': _is.MethodStreamConnector(
          name: 'streamInbox',
          params: {},
          streamParams: {},
          returnType: _is.MethodStreamReturnType.streamType,
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['sync'] as _i609im4b.SyncEndpoint).streamInbox(
                session,
              ),
        ),
      },
    );
    connectors['telemetry'] = _is.EndpointConnector(
      name: 'telemetry',
      endpoint: endpoints['telemetry']!,
      methodConnectors: {
        'update': _is.MethodConnector(
          name: 'update',
          params: {
            'telemetry': _is.ParameterDescription(
              name: 'telemetry',
              type: _is.getType<_i375h7rk.DeviceTelemetry>(),
              nullable: false,
            ),
            'deviceToken': _is.ParameterDescription(
              name: 'deviceToken',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['telemetry'] as _i34lh6ht.TelemetryEndpoint)
                  .update(
                    session,
                    params['telemetry'],
                    params['deviceToken'],
                  ),
        ),
        'getLatest': _is.MethodConnector(
          name: 'getLatest',
          params: {
            'deviceId': _is.ParameterDescription(
              name: 'deviceId',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['telemetry'] as _i34lh6ht.TelemetryEndpoint)
                  .getLatest(
                    session,
                    params['deviceId'],
                  ),
        ),
        'streamTelemetry': _is.MethodStreamConnector(
          name: 'streamTelemetry',
          params: {
            'deviceId': _is.ParameterDescription(
              name: 'deviceId',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          streamParams: {},
          returnType: _is.MethodStreamReturnType.streamType,
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['telemetry'] as _i34lh6ht.TelemetryEndpoint)
                  .streamTelemetry(
                    session,
                    params['deviceId'],
                  ),
        ),
      },
    );
    connectors['voice'] = _is.EndpointConnector(
      name: 'voice',
      endpoint: endpoints['voice']!,
      methodConnectors: {
        'routeVoice': _is.MethodConnector(
          name: 'routeVoice',
          params: {
            'sanitizedTranscript': _is.ParameterDescription(
              name: 'sanitizedTranscript',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['voice'] as _iq0gswfc.VoiceEndpoint).routeVoice(
                    session,
                    params['sanitizedTranscript'],
                  ),
        ),
      },
    );
    modules['serverpod_auth_idp'] = _iais.Endpoints()
      ..initializeEndpoints(server);
    modules['serverpod_auth_core'] = _iacs.Endpoints()
      ..initializeEndpoints(server);
  }

  @override
  _is.FutureCallDispatch? get futureCalls {
    return _i2j7jym1.FutureCalls();
  }
}
