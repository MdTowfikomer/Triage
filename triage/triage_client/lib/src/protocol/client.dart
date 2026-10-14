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
import 'dart:async' as _ida;
import 'package:http/http.dart' as _i85jenna;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _iacc;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _iaic;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'package:triage_client/src/protocol/device_registration_response.dart'
    as _i8krk7ig;
import 'package:triage_client/src/protocol/device_telemetry.dart' as _io3025lv;
import 'package:triage_client/src/protocol/inbox_event.dart' as _i0lnl91c;
import 'package:triage_client/src/protocol/inbox_item.dart' as _iadxe3ww;
import 'package:triage_client/src/protocol/routine_acknowledgement_event.dart'
    as _iwkt1xyi;
import 'package:triage_client/src/protocol/routine_dispatch_event.dart'
    as _il6f6egr;
import 'package:triage_client/src/protocol/routine_schedule.dart' as _ixc37922;
import 'package:triage_client/src/protocol/routine_schedule_response.dart'
    as _iif2lpli;
import 'package:triage_client/src/protocol/voice_action.dart' as _iqzsze1b;
import 'package:triage_client/src/protocol/voice_command_sync_batch.dart'
    as _iygta9x6;
import 'package:triage_client/src/protocol/voice_command_sync_result.dart'
    as _if07coft;
import 'protocol.dart' as _il2as5qe;

/// By extending [EmailIdpBaseEndpoint], the email identity provider endpoints
/// are made available on the server and enable the corresponding sign-in widget
/// on the client.
/// {@category Endpoint}
class EndpointEmailIdp extends _iaic.EndpointEmailIdpBase {
  EndpointEmailIdp(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'emailIdp';

  /// Logs in the user and returns a new session.
  ///
  /// Throws an [EmailAccountLoginException] in case of errors, with reason:
  /// - [EmailAccountLoginExceptionReason.invalidCredentials] if the email or
  ///   password is incorrect.
  /// - [EmailAccountLoginExceptionReason.tooManyAttempts] if there have been
  ///   too many failed login attempts.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  @override
  _ida.Future<_iacc.AuthSuccess> login({
    required String email,
    required String password,
  }) => caller.callServerEndpoint<_iacc.AuthSuccess>(
    'emailIdp',
    'login',
    {
      'email': email,
      'password': password,
    },
  );

  /// Starts the registration for a new user account with an email-based login
  /// associated to it.
  ///
  /// Upon successful completion of this method, an email will have been
  /// sent to [email] with a verification link, which the user must open to
  /// complete the registration.
  ///
  /// Always returns a account request ID, which can be used to complete the
  /// registration. If the email is already registered, the returned ID will not
  /// be valid.
  @override
  _ida.Future<_isc.UuidValue> startRegistration({required String email}) =>
      caller.callServerEndpoint<_isc.UuidValue>(
        'emailIdp',
        'startRegistration',
        {'email': email},
      );

  /// Verifies an account request code and returns a token
  /// that can be used to complete the account creation.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.expired] if the account request has
  ///   already expired.
  /// - [EmailAccountRequestExceptionReason.policyViolation] if the password
  ///   does not comply with the password policy.
  /// - [EmailAccountRequestExceptionReason.invalid] if no request exists
  ///   for the given [accountRequestId] or [verificationCode] is invalid.
  @override
  _ida.Future<String> verifyRegistrationCode({
    required _isc.UuidValue accountRequestId,
    required String verificationCode,
  }) => caller.callServerEndpoint<String>(
    'emailIdp',
    'verifyRegistrationCode',
    {
      'accountRequestId': accountRequestId,
      'verificationCode': verificationCode,
    },
  );

  /// Completes a new account registration, creating a new auth user with a
  /// profile and attaching the given email account to it.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.expired] if the account request has
  ///   already expired.
  /// - [EmailAccountRequestExceptionReason.policyViolation] if the password
  ///   does not comply with the password policy.
  /// - [EmailAccountRequestExceptionReason.invalid] if the [registrationToken]
  ///   is invalid.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  ///
  /// Returns a session for the newly created user.
  @override
  _ida.Future<_iacc.AuthSuccess> finishRegistration({
    required String registrationToken,
    required String password,
  }) => caller.callServerEndpoint<_iacc.AuthSuccess>(
    'emailIdp',
    'finishRegistration',
    {
      'registrationToken': registrationToken,
      'password': password,
    },
  );

  /// Requests a password reset for [email].
  ///
  /// If the email address is registered, an email with reset instructions will
  /// be send out. If the email is unknown, this method will have no effect.
  ///
  /// Always returns a password reset request ID, which can be used to complete
  /// the reset. If the email is not registered, the returned ID will not be
  /// valid.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.tooManyAttempts] if the user has
  ///   made too many attempts trying to request a password reset.
  ///
  @override
  _ida.Future<_isc.UuidValue> startPasswordReset({required String email}) =>
      caller.callServerEndpoint<_isc.UuidValue>(
        'emailIdp',
        'startPasswordReset',
        {'email': email},
      );

  /// Verifies a password reset code and returns a finishPasswordResetToken
  /// that can be used to finish the password reset.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.expired] if the password reset
  ///   request has already expired.
  /// - [EmailAccountPasswordResetExceptionReason.tooManyAttempts] if the user has
  ///   made too many attempts trying to verify the password reset.
  /// - [EmailAccountPasswordResetExceptionReason.invalid] if no request exists
  ///   for the given [passwordResetRequestId] or [verificationCode] is invalid.
  ///
  /// If multiple steps are required to complete the password reset, this endpoint
  /// should be overridden to return credentials for the next step instead
  /// of the credentials for setting the password.
  @override
  _ida.Future<String> verifyPasswordResetCode({
    required _isc.UuidValue passwordResetRequestId,
    required String verificationCode,
  }) => caller.callServerEndpoint<String>(
    'emailIdp',
    'verifyPasswordResetCode',
    {
      'passwordResetRequestId': passwordResetRequestId,
      'verificationCode': verificationCode,
    },
  );

  /// Completes a password reset request by setting a new password.
  ///
  /// The [verificationCode] returned from [verifyPasswordResetCode] is used to
  /// validate the password reset request.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.expired] if the password reset
  ///   request has already expired.
  /// - [EmailAccountPasswordResetExceptionReason.policyViolation] if the new
  ///   password does not comply with the password policy.
  /// - [EmailAccountPasswordResetExceptionReason.invalid] if no request exists
  ///   for the given [passwordResetRequestId] or [verificationCode] is invalid.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  @override
  _ida.Future<void> finishPasswordReset({
    required String finishPasswordResetToken,
    required String newPassword,
  }) => caller.callServerEndpoint<void>(
    'emailIdp',
    'finishPasswordReset',
    {
      'finishPasswordResetToken': finishPasswordResetToken,
      'newPassword': newPassword,
    },
  );

  @override
  _ida.Future<bool> hasAccount() => caller.callServerEndpoint<bool>(
    'emailIdp',
    'hasAccount',
    {},
  );
}

/// By extending [RefreshJwtTokensEndpoint], the JWT token refresh endpoint
/// is made available on the server and enables automatic token refresh on the client.
/// {@category Endpoint}
class EndpointJwtRefresh extends _iacc.EndpointRefreshJwtTokens {
  EndpointJwtRefresh(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'jwtRefresh';

  /// Creates a new token pair for the given [refreshToken].
  ///
  /// If [refreshToken] is omitted, cookie-mode web clients fall back to the
  /// configured HttpOnly refresh cookie. When neither source is present this
  /// throws [RefreshTokenNotFoundException], the same public "no usable refresh
  /// credential" exception used for unknown refresh tokens.
  ///
  /// Can throw the following exceptions:
  /// -[RefreshTokenMalformedException]: refresh token is malformed and could
  ///   not be parsed. Not expected to happen for tokens issued by the server.
  /// -[RefreshTokenNotFoundException]: refresh token is unknown to the server.
  ///   Either the token was deleted or generated by a different server.
  /// -[RefreshTokenExpiredException]: refresh token has expired. Will happen
  ///   only if it has not been used within configured `refreshTokenLifetime`.
  /// -[RefreshTokenInvalidSecretException]: refresh token is incorrect, meaning
  ///   it does not refer to the current secret refresh token. This indicates
  ///   either a malfunctioning client or a malicious attempt by someone who has
  ///   obtained the refresh token. In this case the underlying refresh token
  ///   will be deleted, and access to it will expire fully when the last access
  ///   token is elapsed.
  ///
  /// This endpoint is unauthenticated, meaning the client won't include any
  /// authentication information with the call.
  @override
  _ida.Future<_iacc.AuthSuccess> refreshAccessToken({String? refreshToken}) =>
      caller.callServerEndpoint<_iacc.AuthSuccess>(
        'jwtRefresh',
        'refreshAccessToken',
        {'refreshToken': refreshToken},
        authenticated: false,
      );
}

/// {@category Endpoint}
class EndpointCommandSync extends _isc.EndpointRef {
  EndpointCommandSync(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'commandSync';

  /// Synchronizes a batch of offline voice command records to PostgreSQL idempotently.
  /// Validates authenticated user session, scoped device auth token, and deduplicates entries by eventId.
  _ida.Future<_if07coft.VoiceCommandSyncResult> syncBatch(
    _iygta9x6.VoiceCommandSyncBatch batch,
  ) => caller.callServerEndpoint<_if07coft.VoiceCommandSyncResult>(
    'commandSync',
    'syncBatch',
    {'batch': batch},
  );
}

/// {@category Endpoint}
class EndpointDevAuth extends _isc.EndpointRef {
  EndpointDevAuth(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'devAuth';

  /// Issues a valid, verified authentication session for the development pilot account.
  /// Strictly restricted to local development and test environments.
  _ida.Future<_iacc.AuthSuccess> authenticatePilotUser({
    required String email,
  }) => caller.callServerEndpoint<_iacc.AuthSuccess>(
    'devAuth',
    'authenticatePilotUser',
    {'email': email},
  );
}

/// {@category Endpoint}
class EndpointDevice extends _isc.EndpointRef {
  EndpointDevice(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'device';

  /// Binds device identity to authenticated user ownership, returning a scoped device auth token.
  _ida.Future<_i8krk7ig.DeviceRegistrationResponse> registerDevice(
    String deviceId, {
    String? deviceName,
  }) => caller.callServerEndpoint<_i8krk7ig.DeviceRegistrationResponse>(
    'device',
    'registerDevice',
    {
      'deviceId': deviceId,
      'deviceName': deviceName,
    },
  );
}

/// {@category Endpoint}
class EndpointInbox extends _isc.EndpointRef {
  EndpointInbox(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'inbox';

  _ida.Future<_iadxe3ww.InboxItem> createItem(
    _iadxe3ww.InboxItem item, {
    bool? allowRecording,
    _isc.UuidValue? expectedUserId,
  }) => caller.callServerEndpoint<_iadxe3ww.InboxItem>(
    'inbox',
    'createItem',
    {
      'item': item,
      'allowRecording': allowRecording,
      'expectedUserId': expectedUserId,
    },
  );

  _ida.Future<List<_iadxe3ww.InboxItem>> listItems({
    String? type,
    int? limit,
    int? offset,
  }) => caller.callServerEndpoint<List<_iadxe3ww.InboxItem>>(
    'inbox',
    'listItems',
    {
      'type': type,
      'limit': limit,
      'offset': offset,
    },
  );

  _ida.Future<_iadxe3ww.InboxItem> completeItem(int itemId) =>
      caller.callServerEndpoint<_iadxe3ww.InboxItem>(
        'inbox',
        'completeItem',
        {'itemId': itemId},
      );

  /// Replaces only editable fields; all identity and lifecycle fields stay put.
  _ida.Future<_iadxe3ww.InboxItem> updateItem(
    int itemId,
    String title,
    String? body,
    String? priority,
    DateTime? dueDate,
    List<String>? tags,
  ) => caller.callServerEndpoint<_iadxe3ww.InboxItem>(
    'inbox',
    'updateItem',
    {
      'itemId': itemId,
      'title': title,
      'body': body,
      'priority': priority,
      'dueDate': dueDate,
      'tags': tags,
    },
  );

  _ida.Future<bool> deleteItem(int itemId) => caller.callServerEndpoint<bool>(
    'inbox',
    'deleteItem',
    {'itemId': itemId},
  );
}

/// {@category Endpoint}
class EndpointRoutine extends _isc.EndpointRef {
  EndpointRoutine(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'routine';

  /// Schedules a routine for an authenticated user on a registered device.
  _ida.Future<_iif2lpli.RoutineScheduleResponse> scheduleRoutine({
    required String deviceId,
    required String name,
    required DateTime scheduledTime,
    required String stepsJson,
  }) => caller.callServerEndpoint<_iif2lpli.RoutineScheduleResponse>(
    'routine',
    'scheduleRoutine',
    {
      'deviceId': deviceId,
      'name': name,
      'scheduledTime': scheduledTime,
      'stepsJson': stepsJson,
    },
  );

  /// Connects device WebSocket to real-time routine dispatch messages.
  /// Requires authenticated session and matching device credentials.
  _ida.Stream<_il6f6egr.RoutineDispatchEvent> streamRoutineDispatches({
    required String deviceId,
    required String deviceToken,
  }) =>
      caller.callStreamingServerEndpoint<
        _ida.Stream<_il6f6egr.RoutineDispatchEvent>,
        _il6f6egr.RoutineDispatchEvent
      >(
        'routine',
        'streamRoutineDispatches',
        {
          'deviceId': deviceId,
          'deviceToken': deviceToken,
        },
        {},
      );

  /// Dispatches execution acknowledgement back to Serverpod with per-step outcomes.
  /// Requires authenticated session, device ownership, occurrence verification, and valid state transitions.
  _ida.Future<bool> acknowledgeRoutine(
    _iwkt1xyi.RoutineAcknowledgementEvent ack,
  ) => caller.callServerEndpoint<bool>(
    'routine',
    'acknowledgeRoutine',
    {'ack': ack},
  );

  /// Queries status of a routine (for verification and UI state tracking).
  /// Strictly checks ownership so callers cannot inspect other users' routines.
  _ida.Future<_ixc37922.RoutineSchedule?> getRoutine(String routineId) =>
      caller.callServerEndpoint<_ixc37922.RoutineSchedule?>(
        'routine',
        'getRoutine',
        {'routineId': routineId},
      );
}

/// {@category Endpoint}
class EndpointSync extends _isc.EndpointRef {
  EndpointSync(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'sync';

  _ida.Stream<_i0lnl91c.InboxEvent> streamInbox() =>
      caller.callStreamingServerEndpoint<
        _ida.Stream<_i0lnl91c.InboxEvent>,
        _i0lnl91c.InboxEvent
      >(
        'sync',
        'streamInbox',
        {},
        {},
      );
}

/// {@category Endpoint}
class EndpointTelemetry extends _isc.EndpointRef {
  EndpointTelemetry(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'telemetry';

  /// Pushes latest device telemetry snapshot to PostgreSQL.
  /// Validates user ownership and device token, updates or inserts the record,
  /// and broadcasts the update to real-time subscribers over WebSockets.
  _ida.Future<_io3025lv.DeviceTelemetry> update(
    _io3025lv.DeviceTelemetry telemetry,
    String deviceToken,
  ) => caller.callServerEndpoint<_io3025lv.DeviceTelemetry>(
    'telemetry',
    'update',
    {
      'telemetry': telemetry,
      'deviceToken': deviceToken,
    },
  );

  /// Gets the latest telemetry record for a registered device owned by the authenticated user.
  _ida.Future<_io3025lv.DeviceTelemetry?> getLatest(String deviceId) =>
      caller.callServerEndpoint<_io3025lv.DeviceTelemetry?>(
        'telemetry',
        'getLatest',
        {'deviceId': deviceId},
      );

  /// Real-time stream of telemetry events for a specific device.
  _ida.Stream<_io3025lv.DeviceTelemetry> streamTelemetry(String deviceId) =>
      caller.callStreamingServerEndpoint<
        _ida.Stream<_io3025lv.DeviceTelemetry>,
        _io3025lv.DeviceTelemetry
      >(
        'telemetry',
        'streamTelemetry',
        {'deviceId': deviceId},
        {},
      );
}

/// {@category Endpoint}
class EndpointVoice extends _isc.EndpointRef {
  EndpointVoice(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'voice';

  /// Expects on-device sanitized text. Does not persist or broadcast the input.
  _ida.Future<_iqzsze1b.VoiceActionResult> routeVoice(
    String sanitizedTranscript,
  ) => caller.callServerEndpoint<_iqzsze1b.VoiceActionResult>(
    'voice',
    'routeVoice',
    {'sanitizedTranscript': sanitizedTranscript},
  );
}

class Modules {
  Modules(Client client) {
    serverpod_auth_idp = _iaic.Caller(client);
    serverpod_auth_core = _iacc.Caller(client);
  }

  late final _iaic.Caller serverpod_auth_idp;

  late final _iacc.Caller serverpod_auth_core;
}

class Client extends _isc.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(
      _isc.MethodCallContext,
      Object,
      StackTrace,
    )?
    onFailedCall,
    Function(_isc.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
    _i85jenna.Client? httpClientOverride,
  }) : super(
         host,
         _il2as5qe.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
         httpClientOverride: httpClientOverride,
       ) {
    emailIdp = EndpointEmailIdp(this);
    jwtRefresh = EndpointJwtRefresh(this);
    commandSync = EndpointCommandSync(this);
    devAuth = EndpointDevAuth(this);
    device = EndpointDevice(this);
    inbox = EndpointInbox(this);
    routine = EndpointRoutine(this);
    sync = EndpointSync(this);
    telemetry = EndpointTelemetry(this);
    voice = EndpointVoice(this);
    modules = Modules(this);
  }

  late final EndpointEmailIdp emailIdp;

  late final EndpointJwtRefresh jwtRefresh;

  late final EndpointCommandSync commandSync;

  late final EndpointDevAuth devAuth;

  late final EndpointDevice device;

  late final EndpointInbox inbox;

  late final EndpointRoutine routine;

  late final EndpointSync sync;

  late final EndpointTelemetry telemetry;

  late final EndpointVoice voice;

  late final Modules modules;

  @override
  Map<String, _isc.EndpointRef> get endpointRefLookup => {
    'emailIdp': emailIdp,
    'jwtRefresh': jwtRefresh,
    'commandSync': commandSync,
    'devAuth': devAuth,
    'device': device,
    'inbox': inbox,
    'routine': routine,
    'sync': sync,
    'telemetry': telemetry,
    'voice': voice,
  };

  @override
  Map<String, _isc.ModuleEndpointCaller> get moduleLookup => {
    'serverpod_auth_idp': modules.serverpod_auth_idp,
    'serverpod_auth_core': modules.serverpod_auth_core,
  };
}
