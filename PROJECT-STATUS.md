# Unraid Security — Project Status and Development Roadmap

**Status:** Early development / prototype  
**Production ready:** No  
**Primary goal:** Build a read-only Unraid security auditor that identifies meaningful configuration risks without automatically changing the system.

## Project Vision

`unraid-security` is intended to provide Unraid users with a simple security dashboard that evaluates common security and hardening concerns and presents the results in understandable terms.

The goal is not to turn Unraid into a generic enterprise Linux server or blindly apply security benchmarks designed for other platforms.

The goal is to answer a much more practical question:

> **Is this Unraid server configured in a reasonably secure way, and if not, what should the owner look at?**

The plugin should focus on Unraid-specific risks, explain why each finding matters, and provide useful remediation guidance.

For the initial versions, the plugin should remain **read-only**. It should identify problems, not automatically modify system configuration.

---

## Current State

The repository is currently a **working installation scaffold**, not a functioning security scanner.

The existing structure proves that the plugin can be installed and that files can be placed into the Unraid WebGUI plugin directory, but the advertised security functionality has not yet been implemented.

| Component | Current state |
| --- | --- |
| Plugin installer | Prototype works |
| Security scanner | Stub |
| Security dashboard | Placeholder |
| SSH assessment | Not implemented |
| Share assessment | Not implemented |
| Account/password assessment | Not implemented |
| WAN exposure assessment | Not implemented |
| Remediation guidance | Not implemented |
| Automatic remediation | Intentionally not implemented |
| Background daemon | None |

The current scanner at `src/scripts/security-check.sh` only reports that the security check is a stub and exits successfully.

The current WebGUI page at `src/unraid-security.page.txt` is likewise explicitly marked as a placeholder.

The metadata at `src/plugin.json.txt` also describes the project as a placeholder used for testing the installation structure.

This is therefore best understood as **the foundation for the intended plugin**, rather than a usable security product today.

---

## Security Review of the Current Installer

### 1. Executable code is downloaded from `main`

The most important issue in the existing installation design is in `unraid-security.plg`.

The installer currently downloads plugin files directly from the repository's `main` branch.

That includes the executable security-check script.

Conceptually, the installer does this:

```text
released PLG
    ↓
downloads current contents of main
    ↓
installs those files as the plugin
```

This means a versioned plugin does not actually install an immutable version of the source.

For example, a PLG identifying itself as version `2025.06.25` may install different code depending on what happens to be present on `main` when the installation occurs.

That creates an unnecessary supply-chain risk, particularly because an Unraid plugin can operate with significant access to the host system.

### Recommended design

Released versions should install an immutable release artifact.

```text
source
    ↓
versioned release
    ↓
unraid-security-x.y.z.txz
    ↓
checksum verification
    ↓
Unraid installation
```

A released PLG should never fetch executable code from a mutable development branch.

At minimum:

- package the plugin into a versioned release artifact;
- pin the installer to that artifact;
- publish a cryptographic checksum;
- verify the package before installation;
- ensure a previously released version cannot silently change when `main` changes.

---

## WebGUI Architecture

The current `unraid-security.page.txt` file resembles a Vue single-file component:

```html
<template>
...
</template>

<script>
export default {
    name: "UnraidSecurity"
};
</script>
```

That should not be assumed to work as a conventional Unraid WebGUI `.page` plugin simply because it is placed under:

```text
/usr/local/emhttp/plugins/unraid-security/
```

Before further UI development, the project should make an explicit architecture decision.

The two questions are:

1. Is the plugin targeting the traditional Unraid `emhttp` WebGUI plugin architecture?
2. Or is it targeting the newer Unraid UI/API architecture?

The current repository risks mixing assumptions from the two.

The first meaningful development milestone should establish the supported Unraid architecture and build the UI correctly for that target.

---

## Security Scanner Philosophy

The scanner should begin with three rules.

### 1. Read-only by default

The first production release should inspect configuration but not change it.

A finding should tell the user:

- what was observed;
- whether it is good, questionable, or dangerous;
- why it matters;
- what the user can do about it.

It should not begin rewriting SSH, Samba, networking, or authentication configuration.

Automatic remediation can be considered later, after the detection logic is mature and well tested.

### 2. Unraid-specific recommendations

A generic Linux hardening benchmark is not enough.

Unraid has its own architecture, management model, storage model, WebGUI, shares, Docker integration, remote-access mechanisms, and administrative conventions.

A configuration that looks strange to a generic Linux security scanner may be perfectly normal for Unraid.

Every check should therefore answer:

> Is this actually a security problem on Unraid?

rather than:

> Does this look different from a hardened Ubuntu server?

### 3. Avoid false certainty

The plugin should clearly distinguish among:

- something directly observed on the server;
- something inferred from configuration;
- something the plugin cannot determine locally.

This is especially important for network exposure.

---

## Proposed Finding Model

Every check should return structured data rather than simply printing text.

For example:

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

A common schema makes it possible for the scanner and UI to remain separate.

The backend determines facts.

The UI decides how to display them.

---

## Proposed Scanner Architecture

Rather than allowing one large shell script to accumulate every check, security checks should be modular.

A possible structure:

```text
src/
└── scripts/
    ├── security-check.sh
    └── checks/
        ├── accounts.sh
        ├── ssh.sh
        ├── shares.sh
        ├── network.sh
        ├── services.sh
        ├── webgui.sh
        ├── docker.sh
        ├── updates.sh
        └── filesystem.sh
```

`security-check.sh` acts as the orchestrator.

Individual modules perform narrowly scoped checks and return normalized findings.

This provides several benefits:

- checks can be tested independently;
- new checks can be added without rewriting the scanner;
- failures in one category do not need to break the entire scan;
- severity and output formatting can remain consistent;
- the WebGUI does not need to know how each finding was discovered.

---

## Initial Security Checks

Version 0.1 should resist the temptation to scan everything.

A small number of defensible checks is more valuable than dozens of noisy ones.

A reasonable first release would include approximately the following.

### Accounts

#### Root account protection

Determine whether the administrative account has appropriate authentication protection.

The scanner can safely detect conditions such as an absent password or unexpected account state.

It should **not** claim to know whether a password is "weak" when it does not possess the plaintext password.

For that reason, the existing concept of **weak password detection** should become something more accurate such as:

> **Root account protection**

---

## SSH

Potential checks include:

- `PermitEmptyPasswords`
- `PasswordAuthentication`
- `PubkeyAuthentication`
- SSH listening state
- SSH listening interfaces
- SSH port
- relevant root-login configuration

Findings must account for the fact that Unraid's administrative model differs from that of many conventional Linux servers.

The scanner should report what it sees and evaluate it in the context of Unraid rather than blindly importing generic Linux recommendations.

---

## Shares

Share security should be one of the project's highest-value areas.

Potential findings include:

- publicly writable SMB shares;
- publicly readable shares;
- Secure versus Private share configuration;
- flash/boot-device share exposure;
- NFS exports;
- unexpectedly broad export permissions.

Severity should reflect the actual configuration rather than treating all exported shares as equally dangerous.

For example:

```text
Public read/write share     HIGH
Public read-only share      WARNING
Private authenticated       PASS
```

The exact severity model should be tested and documented before release.

---

## Network Services

The scanner should identify services that commonly deserve scrutiny on an Unraid host.

Initial candidates include:

- Telnet;
- FTP;
- SSH;
- NFS;
- WebGUI listeners;
- other externally listening management services.

Finding a listening service is useful information, but it is not sufficient evidence that the service is exposed to the Internet.

---

## WAN Exposure

WAN exposure is one of the most useful potential features of the project and also one of the easiest to implement incorrectly.

A command such as:

```bash
ss -lntup
```

can determine what the Unraid host is listening to.

It cannot, by itself, determine what the public Internet can reach.

For example:

```text
0.0.0.0:22
```

means SSH is listening on local interfaces.

It does **not** prove that TCP/22 has been forwarded through the user's router.

The project should therefore distinguish between:

### Local listener

A service is accepting connections on one or more interfaces.

### Known or inferred remote exposure

Local configuration provides evidence of a mechanism intended to make the service reachable remotely.

### Externally verified exposure

A service has actually been observed as reachable from outside the local network.

The plugin should never report:

> SSH is exposed to the Internet

when the only evidence is that SSH is listening locally.

Avoiding false positives is essential to making the security score trustworthy.

---

## WebGUI Security

Potential checks include:

- HTTP versus HTTPS configuration;
- management interface listening state;
- remote-management settings;
- unexpected interface exposure;
- other security-relevant WebGUI configuration.

These checks should be based on documented Unraid behavior and tested against supported Unraid versions.

---

## Updates

The scanner should report the state of the Unraid OS version when that information can be obtained reliably.

The goal is not necessarily to demand the newest release immediately.

Instead, it should identify whether:

- the system appears current;
- a newer supported release is available;
- the running version has known support or security implications that warrant attention.

---

## Proposed Dashboard

The dashboard should emphasize findings rather than decoration.

A useful first version might look conceptually like this:

```text
UNRAID SECURITY
────────────────────────────────────

Overall assessment: Needs Attention

CRITICAL
✗ Telnet enabled

HIGH
✗ Public writable share: Media
✗ Flash share exported over SMB

MEDIUM
⚠ SSH password authentication enabled
⚠ HTTPS not enforced

GOOD
✓ Root account protected
✓ NFS disabled
✓ FTP disabled

[View all findings]
```

Every finding should be expandable into something like:

```text
Finding:
SSH password authentication is enabled.

Observed:
PasswordAuthentication yes

Why this matters:
Password authentication increases exposure to
credential guessing and stolen-password attacks.

Recommendation:
Consider SSH key authentication where practical.

Automatic change:
None. This plugin is read-only.
```

The important feature is not the score.

The important feature is that the user understands the finding.

---

## Security Scoring

A numeric score may eventually be useful, but it should not be introduced until the severity model is defensible.

A superficially precise score such as:

```text
Security Score: 82/100
```

is worse than no score if the weighting behind it is arbitrary.

Early versions should prefer:

```text
Critical
High
Medium
Informational
Pass
```

Once enough checks exist and their relative importance has been validated, an aggregate score can be added.

---

## Version 0.1 Target

The first meaningful release should focus on approximately 10–12 checks.

Suggested initial scope:

1. Root account protection
2. Telnet enabled/disabled
3. FTP enabled/disabled
4. SSH `PermitEmptyPasswords`
5. SSH password-authentication state
6. SSH listening state and interfaces
7. Public writable shares
8. Flash/boot share exposure
9. NFS exports
10. WebGUI HTTPS configuration
11. Remote-management exposure indicators
12. Unraid update status

Success for version 0.1 should mean:

> Every reported finding is something the project can explain and defend.

Not:

> The project has the largest possible number of checks.

---

## Testing Requirements

Security software must earn trust.

Each check should have test fixtures representing at least:

- known-good configuration;
- known-bad configuration;
- missing configuration;
- malformed configuration;
- unexpected but valid configuration.

Where Unraid behavior differs among supported releases, version-specific tests should be added.

The scanner should fail conservatively.

If it cannot determine something reliably, the result should be:

```text
UNKNOWN
```

rather than manufacturing a PASS or FAIL.

---

## Packaging Requirements

Before the project is considered releasable:

- executable code must not be pulled from `main`;
- releases must be immutable;
- packages should be versioned;
- package integrity should be verifiable;
- installation failures should stop safely;
- uninstall should remove only files owned by the plugin;
- supported Unraid versions should be explicitly tested;
- the WebGUI implementation should use the architecture appropriate to those versions.

---

## What the Project Is Not

The plugin is not intended to be:

- an antivirus product;
- an intrusion-detection system;
- a vulnerability scanner for every Docker container;
- an Internet perimeter scanner;
- an enterprise compliance platform;
- an automatic hardening engine.

At least initially, its job is much simpler:

> **Look at an Unraid server the way a security-minded administrator would, identify meaningful configuration risks, and explain them clearly.**

That is enough to make the project useful.

---

## Current Assessment

The repository today is a prototype, not a security product.

That is not a reason to abandon it.

The existing installation work establishes a starting point. The next phase should shift away from placeholder UI work and toward three fundamentals:

1. **Correct plugin architecture**
2. **Secure, immutable packaging**
3. **A small set of trustworthy read-only security checks**

Once those exist, the dashboard becomes a way of presenting a real security model rather than a shell waiting for one.

The core idea remains strong:

> Give ordinary Unraid administrators a clear answer to **"What on my server should I be worried about?"** without requiring them to become Linux security specialists first.

That is the product worth building.
