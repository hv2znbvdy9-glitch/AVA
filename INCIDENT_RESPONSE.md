# Incident Response

This procedure is for suspected compromise of AVA repository accounts,
credentials, integrations, or project data. It is a human-operated guide; this
repository does not have privileged access to revoke GitHub accounts or
credentials automatically.

## 1. Report and assess

- Report suspected security incidents privately to a repository owner. Do not
  post tokens, private data, or exploit details in a public issue.
- Record the time reported, affected repository/account/integration, observed
  symptoms, and a severity estimate. Keep the record factual and limit access
  to people who need it.
- Treat a potentially exposed credential as compromised; do not test it by
  using it.

## 2. Contain

An authorized owner should promptly take the least disruptive containment
actions appropriate to the evidence:

- Remove or suspend affected repository access and review team membership.
- Revoke or rotate affected personal access tokens, deploy keys, OAuth grants,
  GitHub App credentials, webhook secrets, and other credentials through their
  issuing settings.
- Disable or uninstall a suspect integration if necessary, after considering
  service impact.
- If code may be affected, pause merges or deployments using GitHub settings
  until a trusted owner has assessed the risk.

Do not retaliate, publicly identify a suspected person, or destroy evidence.

## 3. Preserve and investigate

Preserve relevant GitHub audit logs, security alerts, workflow runs, pull
requests, commit references, and timestamps where available. Record who
collected each item and where it is stored. Repository history does not capture
all account, app, or settings activity; audit-log availability and retention
depend on GitHub's plan and organization configuration.

Determine the likely entry point, scope, affected versions or data, and whether
credentials or downstream systems may be exposed. Avoid collecting unrelated
personal data. Escalate incidents involving GitHub infrastructure or third-party
services to their respective providers.

## 4. Eradicate and recover

Remove unauthorized changes only after preserving evidence. Rotate affected
secrets, restore trusted code from reviewed commits, verify required CI checks,
and re-enable paused operations only after an owner confirms containment.
Communicate material impact to affected people through an appropriate private
channel, subject to applicable obligations.

## 5. Close and improve

Record a concise timeline, decisions, scope, remediation, and follow-up owners.
Review access and integration permissions after the incident; remove temporary
emergency grants. Document lessons and update this procedure or related controls
as needed. Retain the incident record only as long as required by the project's
applicable policies and legal obligations.

## Emergency access

If normal owner access is unavailable, use only an existing trusted GitHub
owner's authorized break-glass access. Record the reason, actions, and duration,
then review and remove temporary access when normal control is restored. Do not
create or share credentials in this repository.
