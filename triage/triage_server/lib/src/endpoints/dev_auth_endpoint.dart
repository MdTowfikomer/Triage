import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';

import '../generated/protocol.dart';

class DevAuthEndpoint extends Endpoint {
  /// Issues a valid, verified authentication session for the development pilot account.
  /// Strictly restricted to local development and test environments.
  Future<AuthSuccess> authenticatePilotUser(
    Session session, {
    String email = 'pilot@triage.local',
  }) async {
    if (session.serverpod.runMode != 'development' &&
        session.serverpod.runMode != 'test') {
      throw TriageException(
        code: 'forbidden',
        message:
            'DevAuthEndpoint is strictly restricted to local development environments.',
      );
    }

    // Look up or persist consistent pilot user profile
    final existingProfile = await UserProfile.db.findFirstRow(
      session,
      where: (t) => t.email.equals(email),
    );

    final UuidValue authUserId;
    if (existingProfile != null) {
      authUserId = existingProfile.authUserId;
    } else {
      final user = await AuthServices.instance.authUsers.create(session);
      authUserId = user.id;
      await UserProfile.db.insertRow(
        session,
        UserProfile(
          authUserId: authUserId,
          email: email,
          userName: email.split('@').first,
          fullName: email == 'pilot@triage.local'
              ? 'Triage Pilot'
              : 'Triage User',
        ),
      );
    }

    return await AuthServices.instance.tokenManager.createToken(
      session,
      authUserId: authUserId,
      method: 'email',
      scopes: {},
    );
  }
}
