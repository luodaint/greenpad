# Contributing to Greenpad

Thanks for helping make a small, useful Mac editor.

1. Open an issue before starting a substantial feature. Include the everyday editing task you want to improve.
2. Fork the repository and create a branch for your change.
3. Build with `bash build.sh` and run the core and UI tests described in the README. Include regression checks for changes to saving, encodings, searching, or undo.
4. Submit a pull request against `main`. Explain the behavior before and after, include validation, and add a screenshot for visible changes.

Keep changes focused. Use native AppKit controls, preserve keyboard access and undo, and avoid adding dependencies without a clear need. Never commit credentials, private documents, signing certificates, provisioning profiles, or user paths. AI-assisted contributions are welcome; the contributor remains responsible for understanding and validating the change.

All files require review by the maintainer. A pull request does not grant write access. External-contributor CI runs require maintainer approval. Merging and releases remain the maintainer's decision. Submit contributions under the project's MIT license.

Treat other people respectfully. Be specific and constructive in issues and reviews. The maintainer may close disruptive or unrelated discussions.

Report vulnerabilities privately using the process in SECURITY.md.
