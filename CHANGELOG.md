# Changelog

## 1.0.0 - 2026-09-04

Initial working base model.

- Replaced the placeholder Vue UI with a traditional Unraid WebGUI `.page` implementation.
- Added a read-only scanner that emits structured JSON.
- Added checks for root account protection, Telnet, FTP, SSH authentication, public SMB shares, flash-share exposure, public NFS exports, WebGUI TLS, common management listeners, and installed Unraid version.
- Explicitly distinguishes local listeners from proven Internet exposure.
- Added fixture-based tests for insecure and secure configurations.
- Reworked the plugin installer so runtime source is installed from an immutable pinned Git commit rather than executing whatever happens to be on `main` at install time.
