import 'dart:convert';
import 'dart:io';

import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod/serverpod.dart' as serverpod;
import 'package:serverpod_auth_idp_server/providers/email.dart';
import 'package:serverpod_cloud_storage/serverpod_cloud_storage.dart';

import 'src/generated/serverpod.dart';

/// The starting point of the Serverpod server.
void run(List<String> args) async {
  // Initialize Serverpod. The generated Serverpod class is already connected
  // with your project's generated code.
  final pod = Serverpod(args);

  configureAuthentication(pod);

  // Configure only private storage. Recording metadata is explicitly opt-in;
  // upload/download authorization endpoints are a later integration task.
  pod.addCloudStorage(
    await ServerpodCloudProvider.private(
      fallback: () => DatabaseCloudStorage('private'),
    ),
  );

  await pod.start();
}

/// Shared production/test setup using only the official auth implementation.
void configureAuthentication(serverpod.Serverpod pod) {
  // Initialize authentication services for the server.
  pod.initializeAuthServices(
    tokenManagerBuilders: [
      // Use JWT for authentication keys towards the server.
      JwtConfigFromPasswords(),
    ],
    identityProviderBuilders: [
      // Configure email authentication with real outbound delivery via Resend
      EmailIdpConfigFromPasswords(
        sendRegistrationVerificationCode: (
          session, {
          required email,
          required accountRequestId,
          required verificationCode,
          required transaction,
        }) async {
          // Always log to console as well for instant debugging
          session.log('Email verification code for $email: $verificationCode');

          final resendApiKey =
              session.serverpod.getPassword('resendmailapikey');
          if (resendApiKey == null || resendApiKey.isEmpty) {
            session.log(
              'Warning: resendmailapikey not configured in passwords.yaml',
              level: serverpod.LogLevel.warning,
            );
            return;
          }

          final client = HttpClient();
          try {
            final request = await client.postUrl(
              Uri.parse('https://api.resend.com/emails'),
            );
            request.headers.set('Authorization', 'Bearer $resendApiKey');
            request.headers.set('Content-Type', 'application/json');

            final payload = jsonEncode({
              'from': 'Triage <onboarding@resend.dev>',
              'to': [email],
              'subject': 'Your Triage Verification Code: $verificationCode',
              'html': '''
                <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; padding: 24px; background: #F8F7F2; color: #242521; max-width: 480px; margin: 0 auto; border-radius: 12px; border: 1px solid #E5E3DC;">
                  <h2 style="margin-top: 0; color: #181916;">Welcome to Triage</h2>
                  <p style="font-size: 15px; color: #5B5A55; line-height: 1.5;">Here is your verification code to complete sign in:</p>
                  <div style="background: #FFFFFF; padding: 16px; border-radius: 8px; text-align: center; margin: 20px 0; border: 1px solid #E5E3DC;">
                    <span style="font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #E78A4E; font-family: monospace;">$verificationCode</span>
                  </div>
                  <p style="font-size: 13px; color: #8F8E87; margin-bottom: 0;">This code expires in 15 minutes. If you did not request this, you can safely ignore this email.</p>
                </div>
              ''',
            });

            request.write(payload);
            final response = await request.close();
            if (response.statusCode >= 200 && response.statusCode < 300) {
              session.log('Successfully sent Resend email to $email');
            } else {
              final responseBody =
                  await response.transform(utf8.decoder).join();
              session.log(
                'Resend API error (${response.statusCode}): $responseBody',
                level: serverpod.LogLevel.error,
              );
            }
          } catch (e, st) {
            session.log(
              'Failed to deliver email via Resend: $e',
              level: serverpod.LogLevel.error,
              stackTrace: st,
            );
          } finally {
            client.close();
          }
        },
      ),
    ],
  );
}
