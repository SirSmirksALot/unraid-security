# unraid-security

A **read-only security configuration auditor for Unraid**. It checks a small set of high-value settings, explains what it found, and recommends what to review without changing the server.

> [!IMPORTANT]
> **v1.0.0 is a base working model.** The scanner and WebGUI are implemented and fixture-tested, but this release still needs broader testing on real Unraid 6.12/7.x systems before it should be treated as a mature security control.

## What v1 checks

- root account password protection;
- Telnet listener state;
- traditional FTP listener state;
- SSH listener state;
- SSH `PermitEmptyPasswords`;
- SSH `PasswordAuthentication`;
- exported SMB shares using Unraid Public security mode;
- boot/flash share SMB exposure;
- public NFS user-share exports;
- WebGUI SSL/TLS configuration;
- common local management listeners;
- installed Unraid version.

The scanner intentionally does **not** claim that a local listening port is Internet-accessible. Router port forwarding, UPnP, reverse proxies, and true external reachability are separate questions.

## Installation

In Unraid, go to **Plugins → Install Plugin** and use:

```text
https://raw.githubusercontent.com/SirSmirksALot/unraid-security/main/unraid-security.plg
```

After installation, open **Settings → User Utilities → Unraid Security** (menu placement can vary slightly by Unraid version/theme).

## Design

v1 is deliberately conservative:

- **Read-only:** it does not rewrite SSH, Samba, NFS, account, or WebGUI settings.
- **Unraid-specific:** checks are based on Unraid configuration rather than generic Linux-hardening assumptions.
- **Explainable:** every finding includes the observed state, why it matters, and a recommendation.
- **Structured:** the scanner emits JSON so the WebGUI is separate from detection logic.
- **No false certainty:** `unknown` is preferred over inventing a pass/fail result.

The scanner lives at:

```text
/usr/local/emhttp/plugins/unraid-security/scripts/security-check.sh
```

and emits output shaped like:

```json
{
  "scanner_version": "1.0.0",
  "generated_at": "2026-09-04T18:00:00Z",
  "findings": [
    {
      "id": "ssh-password-auth",
      "category": "ssh",
      "title": "SSH password authentication",
      "status": "warning",
      "severity": "medium",
      "observed": "PasswordAuthentication yes",
      "reason": "...",
      "recommendation": "..."
    }
  ]
}
```

## Development

Run the fixture tests on a Linux development machine with Bash and Python 3:

```bash
bash tests/run-tests.sh
```

The scanner supports path overrides used by the test harness, allowing Unraid-like configuration trees to be tested without modifying the development system.

## v1 limitations

- no automatic remediation;
- no external/WAN port scan;
- no router or firewall inspection;
- no Docker-container vulnerability scanning;
- no package/CVE database integration;
- no password cracking or password-strength inference from hashes;
- update check reports the installed Unraid version but does not contact Unraid to determine whether a newer release exists.

For the design rationale and longer roadmap, see **[PROJECT-STATUS.md](PROJECT-STATUS.md)**.

## Safety model

This project should remain boring in the best possible way: inspect, report, explain. A security plugin that changes a NAS automatically can create more risk than it removes, so remediation is intentionally outside the v1 scope.
