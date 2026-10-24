# Security Policy

## Reporting a vulnerability

Do not report an unpatched vulnerability in a public issue, pull request, or
discussion. If private vulnerability reporting is enabled, use the repository's
**Security** tab to create a private vulnerability report. If it is not
available, contact a repository owner privately through GitHub and ask for a
secure reporting channel. Include affected versions or commits, impact, and
reproduction steps; avoid sending real user data or credentials.

For an urgent active incident, follow [INCIDENT_RESPONSE.md](INCIDENT_RESPONSE.md).
Do not attempt to access accounts, systems, or data without authorization while
investigating.

## Response targets

The maintainers aim to acknowledge a report within **3 business days**, provide
an initial severity and triage update within **7 calendar days**, and share
progress at least weekly while the report remains active. These are targets,
not a guarantee of a fix or a substitute for reporting an immediate threat to
the relevant service provider.

Coordinated disclosure timing will be agreed with the reporter. Maintainers
will avoid publishing identifying reporter information without consent and
will coordinate a fix and advisory when appropriate.

## Supported versions

Unless a release-specific support policy is published, report security issues
against the latest version on the default branch. A fix for an older version is
not guaranteed.

## Security contact and bounty

Use private vulnerability reporting in this repository when available; otherwise
contact a repository owner privately through GitHub. No dedicated security
email address or bug bounty program is currently designated by this policy.

## Scope and repository controls

Most repository workflows limit `GITHUB_TOKEN` to read-only `contents`. The
scheduled run monitor uses `actions: read` to fetch run status and `issues:
write` to post its issue comments. These workflow permissions limit their
tokens, but do not configure organization-wide app approvals, webhook
allowlists, branch protection, 2FA, SSO, audit retention, or collaborator
permissions. Those controls must be reviewed and configured by GitHub owners in
the relevant settings.

See [ACCESS_CONTROL.md](ACCESS_CONTROL.md) for access review responsibilities
and [INCIDENT_RESPONSE.md](INCIDENT_RESPONSE.md) for response procedures.
