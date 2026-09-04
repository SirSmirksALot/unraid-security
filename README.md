# unraid-security

A planned **read-only security auditor for Unraid** designed to help server owners identify meaningful configuration risks and understand what to do about them.

> [!IMPORTANT]
> **This project is currently an early-development prototype and is not production ready.**
> The repository contains the plugin installation scaffold, but the security checks and dashboard are not yet implemented.

## Goal

The project is intended to answer a practical question:

> **Is this Unraid server configured in a reasonably secure way, and if not, what should the owner look at?**

Rather than blindly applying generic Linux hardening rules, `unraid-security` will focus on risks that make sense specifically for Unraid.

The initial design is deliberately **read-only**: detect, explain, and recommend — but do not automatically rewrite system configuration.

## Current Status

Today, the repository is primarily an installation and UI scaffold.

| Component | Status |
| --- | --- |
| Plugin installer | Prototype |
| Security scanner | Stub |
| Security dashboard | Placeholder |
| SSH assessment | Planned |
| Share assessment | Planned |
| Account protection checks | Planned |
| Network/service assessment | Planned |
| WAN exposure assessment | Planned |
| Remediation guidance | Planned |
| Automatic remediation | Not planned for the initial release |

The current `security-check.sh` script is only a stub, and the current WebGUI page is a placeholder.

For the detailed technical review, architecture notes, security concerns, and development roadmap, see **[PROJECT-STATUS.md](PROJECT-STATUS.md)**.

## Planned Initial Checks

The first useful release is expected to focus on a small set of checks that can be explained and defended, including:

- root account protection;
- Telnet state;
- FTP state;
- SSH authentication settings;
- SSH listening state and interfaces;
- public writable shares;
- flash/boot share exposure;
- NFS exports;
- WebGUI HTTPS configuration;
- remote-management exposure indicators;
- Unraid update status.

The goal is not to maximize the number of checks. The goal is to minimize false positives and make every finding useful.

## Design Principles

### Read-only first

The plugin should inspect and report before it ever considers changing configuration automatically.

A useful finding should explain:

- what was observed;
- how serious it is;
- why it matters;
- what the user can do about it.

### Unraid-specific

Unraid is not a generic hardened Linux server. Recommendations need to account for Unraid's administration model, shares, WebGUI, Docker integration, networking, and remote-access mechanisms.

### No false certainty

The scanner should distinguish between facts it can observe locally and things it cannot know.

For example, a service listening on `0.0.0.0:22` does **not** by itself prove that SSH is exposed to the public Internet. Router configuration and external reachability are separate questions.

### Structured findings

Security checks should eventually return normalized results that the UI can consume independently, for example:

```json
{
  "id": "ssh-password-auth",
  "category": "ssh",
  "title": "SSH password authentication",
  "status": "warning",
  "severity": "medium",
  "observed": "PasswordAuthentication yes",
  "recommended": "Use SSH keys where practical",
  "reason": "Password authentication increases exposure to credential attacks."
}
```

## Roadmap

The next major milestones are:

1. establish the correct Unraid WebGUI/plugin architecture;
2. replace mutable `main`-branch installation with immutable, versioned release packaging and integrity verification;
3. implement the first set of read-only security checks;
4. add test fixtures for known-good, known-bad, missing, and malformed configurations;
5. build the dashboard around real scanner output;
6. validate behavior across supported Unraid versions.

See **[PROJECT-STATUS.md](PROJECT-STATUS.md)** for the full roadmap.

## What This Project Is Not

At least initially, `unraid-security` is not intended to be:

- antivirus software;
- an intrusion-detection system;
- a vulnerability scanner for every Docker container;
- an Internet perimeter scanner;
- an enterprise compliance product;
- an automatic hardening engine.

Its job is simpler:

> **Look at an Unraid server the way a security-minded administrator would, identify meaningful configuration risks, and explain them clearly.**

## Contributing

The project is still defining its security model and architecture. Issues and contributions that improve Unraid-specific detection accuracy, reduce false positives, strengthen packaging, or add well-tested checks are welcome.

Security findings should be based on observable behavior and documented Unraid configuration rather than generic assumptions wherever possible.

## Development Status

Expect breaking changes while the project is in prototype development.

Do not rely on the current repository as a production security control.
