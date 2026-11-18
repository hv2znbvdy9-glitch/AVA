# Access Control

This policy describes the intended access model for the AVA repository. It does
not mean that GitHub organization teams, branch rules, app permissions, or audit
settings have been configured. Only repository/organization owners can apply and
verify those settings in GitHub. This repository cannot configure access for
DEVITO or AVA-007.

## Roles and responsibilities

Grant the least privilege needed for a person's current work. GitHub's
repository roles are not interchangeable with team names:

| Intended role | GitHub access | Responsibilities and limits |
| --- | --- | --- |
| Owner / administrator | Admin | Repository settings, access decisions, security settings, and incident coordination. Limit this role to trusted repository owners. |
| Maintainer | Maintain, or Write if Maintain is unavailable | Review and merge pull requests, triage issues, and coordinate releases. Do not grant Admin solely to permit merges. |
| Contributor | Write | Work on branches and submit pull requests. Protected branches must reject direct pushes. |
| Issue manager | Triage | Manage issues, labels, and milestones without write access to code. |
| Public reader | Read | View the public repository and participate where GitHub permits. |

Suggested team names are `maintainers`, `core-contributors`,
`documentation-team`, `external-reviewers`, and `security-team`. Team
membership and permissions must be created and reviewed by an organization or
repository owner; this file does not create teams.

| Team | Least-privilege starting point | Important limitation |
| --- | --- | --- |
| `maintainers` | Maintain | Use Admin only for designated owners who must manage repository settings or security. |
| `core-contributors` | Write | A protected-branch rule is needed to prevent direct pushes to the default branch. |
| `documentation-team` | Write, with documentation paths routed through `CODEOWNERS` if configured | GitHub repository roles do not restrict Write access to selected paths; CODEOWNERS requests review but is not a write-access boundary. |
| `external-reviewers` | Read | Review/comment capabilities depend on repository visibility and GitHub access; do not grant Write just to obtain review. |
| `security-team` | Read, with security-alert access only if separately supported and granted | Admin access permits code and settings changes and therefore cannot satisfy “security-only, cannot modify core code.” Do not grant Admin on that basis. |

## Permission matrix

| Action | Owner / Admin | Maintainer | Contributor | Issue manager | Reader |
| --- | --- | --- | --- | --- | --- |
| View code and issues | Yes | Yes | Yes | Yes | Yes |
| Create branches / pull requests | Yes | Yes | Yes | No | No |
| Review and comment on pull requests | Yes | Yes | Yes | As permitted by GitHub | As permitted by GitHub |
| Merge pull requests | Yes | Yes, if granted | No | No | No |
| Manage issues, labels, milestones | Yes | Yes | Limited | Yes | No |
| Change repository settings or access | Yes | No | No | No | No |

## Pull-request and branch protections

The intended policy is that changes enter protected branches through reviewed
pull requests, with required CI checks, no force pushes, and signed commits if
the repository's signing policy is enabled. Repository files and CI workflows
cannot enforce GitHub branch protection or rulesets. An owner must configure
rules for the default branch (and any release/development branches), select the
actual required status checks, and verify the effective rules in GitHub
Settings. Do not claim these protections are active until verified there.

## Access requests and reviews

1. Request access through a repository issue or the repository owner, stating
   the GitHub username, requested role, repository, work needed, and expected
   end date. Do not put secrets or sensitive incident details in a public
   issue.
2. An owner verifies the request and grants the narrowest suitable role or
   team membership. Record the approval and change in the repository's
   administrative audit log where available.
3. Review membership and collaborator access at least quarterly, and after
   role changes or departures. Remove access that is no longer needed. A
   90-day inactivity check may identify accounts for review, but inactivity
   alone is not proof of misuse and should not trigger unreviewed automatic
   revocation.
4. For an access change, confirm the resulting role in GitHub and record who
   approved it, what changed, and when.

## Revocation and emergency access

For a departure, compromised account, or suspected unauthorized access, an
owner should promptly remove the affected collaborator/team membership and
revoke relevant credentials or app installations through GitHub settings.
Preserve available audit evidence before it expires. For a suspected
compromise, prioritize containment and follow [INCIDENT_RESPONSE.md](INCIDENT_RESPONSE.md).

Keep at least two trusted owners where feasible to reduce lockout risk. Use
break-glass access only for a documented emergency, grant it to a named trusted
owner, record the reason and time, and remove temporary access once the
emergency is resolved. Never automate punitive actions or disclose private
identity information.

## Apps, tokens, webhooks, and audit

An owner should periodically inventory installed GitHub Apps, OAuth grants,
webhooks, deploy keys, and personal access tokens; retain only integrations
with a documented need and minimum required permissions/events. Review
repository and organization audit logs where the plan exposes them. Log access
decisions in GitHub's audit facilities when available; Git history is not a
record of account or app access.

Automated access reviews, alerts, audit-log exports, immutable retention, and
permission revocation require an appropriately authorized GitHub integration
and owner-managed configuration. They are not implemented by this repository.
Do not add an admin token or other credential to source code or workflow
secrets for this purpose without a separately reviewed design.
