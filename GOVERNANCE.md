# Project governance

Greenpad is maintained by Marc Llopart ([@mllopart](https://github.com/mllopart)) under the Luodaint organization.

The public can read, fork, report issues, and submit pull requests. Public visibility does not grant write, merge, release, or settings access. The maintainer controls the roadmap, final reviews, releases, and access grants. Existing organization owners retain the administrative powers GitHub assigns them.

`main` requires an approving code-owner review, passing `build-and-test` CI, resolved review conversations, and linear history for ordinary contributions. New commits dismiss old approvals. Force pushes and branch deletion are disabled. CODEOWNERS covers every path, including the workflow and CODEOWNERS itself.

Branch protection applies to administrators. Only `@mllopart` has an explicit bypass of pull-request requirements so the sole maintainer can land their own work without being required to approve their own pull requests. CI and other protections remain required. Bypass is for maintainer changes or emergencies, not an alternative contributor workflow. Push access to `main` is restricted to the maintainer; organization administrators retain the powers GitHub assigns them. Only the maintainer should be granted repository administration.

Automation has read-only repository permissions, does not create or approve PRs, and has no deployment or signing credentials. Contributor code runs only on GitHub-hosted runners after approval. Public release signing and publication are manual maintainer operations.

These controls govern this repository and official releases. The MIT license allows independent forks and redistribution.
