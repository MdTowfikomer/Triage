# Security policy

## Reporting a vulnerability

Please do not report exploitable vulnerabilities, exposed credentials, or
personal data in a public issue. Use the private vulnerability reporting
feature of the repository hosting service when enabled, or contact the
maintainers privately through that service.

Include the affected version, impact, and steps to reproduce without using real
accounts or data. We will acknowledge reports and coordinate a fix and
disclosure timeline with the reporter.

## Handling credentials and user data

Keep production credentials in the hosting platform's secret store and Android
signing material outside version control. Revoke and rotate any credential
that may have been exposed. Do not send raw audio, private contact details, or
authentication tokens in bug reports.
