# Security policy

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting at:

https://github.com/luodaint/greenpad/security/advisories/new

Include affected versions, steps to reproduce, expected impact, and a minimal sample without private data. Do not publish exploit details in a public issue before the maintainer has had an opportunity to investigate. Response times are best effort for this early project; no response SLA is promised.

## Supported versions

Security fixes target the latest source on `main`. The project is currently a pre-release; there are no notarized public releases yet.

## Development boundaries

The editor uses the user's normal filesystem access. It is not currently App-Sandboxed. Opening a document does not execute its contents. Greenpad has no network services, analytics, plugin loader, or automatic updater. This does not imply that arbitrary files or contributor code are trustworthy.

Do not run unreviewed pull-request code on a personal Mac with sensitive files. CI uses disposable GitHub-hosted runners, read-only tokens, no persistent checkout credentials, and no secrets. Avoid `pull_request_target` for executing contributor changes. Workflow actions must be pinned to immutable commit SHAs.

Before distributing binaries, use a maintainer-controlled Developer ID certificate and Apple notarization. Signing materials must never be committed or exposed to fork pull requests.
