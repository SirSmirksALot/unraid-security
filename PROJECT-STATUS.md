# Unraid Security — Project Status

**Current version:** 1.0.0  
**Status:** Working base model / early testing  
**Safety model:** Read-only  
**Minimum declared Unraid version:** 6.12.0

## v1 status

The repository is no longer just an installation scaffold. v1 contains a functioning Bash scanner and a traditional Unraid WebGUI `.page` dashboard.

The scanner emits structured JSON. The WebGUI renders each finding with its status, severity, observed state, reason, and recommended next step. The plugin does not automatically change any Unraid setting.

## Implemented checks

v1 checks:

1. root account password protection;
2. Telnet listener state;
3. traditional FTP listener state;
4. SSH listener state;
5. SSH `PermitEmptyPasswords`;
6. SSH `PasswordAuthentication`;
7. exported SMB user shares configured as Public;
8. boot/flash SMB share exposure and security mode;
9. public NFS user-share exports;
10. WebGUI SSL/TLS mode;
11. common local management listeners;
12. installed Unraid version.

The installed-version check is informational. v1 does not contact Unraid and therefore does not claim to know whether the installed version is current.

## Important boundary: local listener vs. WAN exposure

v1 does **not** call a locally listening service "Internet exposed."

For example, SSH listening on `0.0.0.0:22` means the Unraid host is accepting connections on local interfaces. It does not prove that the router forwards TCP/22 from the public Internet.

WAN exposure can depend on router forwarding, UPnP/NAT-PMP, reverse proxies, VPN or mesh networking, Unraid remote-access configuration, and upstream firewall rules. A future external validation feature should remain separate from the local scanner.

## Architecture

### Scanner

Runtime path:

```text
/usr/local/emhttp/plugins/unraid-security/scripts/security-check.sh
```

The scanner is Bash and has no daemon or persistent background process. It runs on demand when the WebGUI page is loaded or refreshed.

### WebGUI

Runtime page:

```text
/usr/local/emhttp/plugins/unraid-security/unraid-security.page
```

v1 uses the established Unraid `.page` format with PHP instead of the original placeholder Vue component. It is placed under the Settings/User Utilities area using `Menu="OtherSettings"`.

### Configuration reads

The scanner reads normal Unraid/Linux runtime state, including:

```text
/etc/shadow
/etc/ssh/sshd_config
/boot/config/shares/*.cfg
/boot/config/flash.cfg
/boot/config/ident.cfg
/etc/unraid-version
```

It also inspects local TCP listeners using `ss` when available, with a `netstat` fallback.

## Packaging

The original prototype installer downloaded runtime files from mutable `main` during installation. v1 removes that behavior: the installer is generated against an exact Git commit and downloads runtime source from that immutable revision.

This is a substantial improvement over executing whatever happens to be on `main`, but the mature distribution target remains a versioned release artifact with checksum verification.

## Testing status

v1 includes fixture-based tests for intentionally insecure and secure configurations. The tests verify valid JSON output and the principal account, service, SSH, SMB, flash-share, NFS, TLS, and version findings.

The code has also been checked for Bash syntax, the WebGUI PHP has been linted, and the plugin XML is validated before merge.

**The remaining gap is live testing on real Unraid systems.** v1 should therefore be treated as an early base release until it has been exercised on real 6.12 and 7.x servers with different configurations and themes.

## Security decisions

- **Read-only:** no automatic remediation.
- **Password strength:** no cracking and no pretend strength inference from password hashes.
- **Public SMB:** exported Public shares are treated as high risk because guest users receive read/write access.
- **Boot device:** Public flash sharing is critical; other exported modes still receive warnings.
- **WebGUI TLS:** v1 evaluates the local management setting but does not validate certificate trust, expiry, reverse-proxy TLS, or every access path.
- **WAN:** local listeners are evidence of local service availability, not proof of public reachability.

## Known limitations

v1 is not antivirus, IDS/IPS, a CVE scanner, a Docker image scanner, an Internet perimeter scanner, a router auditor, or an automatic hardening engine.

It also does not yet inspect Docker privilege/capability settings, deeply audit Unraid Connect/Tailscale, inspect every custom Samba configuration, or retain historical scan results.

## Next priorities

The next work should be driven by real-server testing rather than by adding a large number of speculative checks:

1. install v1 on real Unraid 6.12 and 7.x systems;
2. verify page placement and rendering across built-in themes;
3. compare every finding against the WebGUI setting that produced it;
4. fix false positives before adding checks;
5. move distribution to immutable release assets with integrity verification;
6. add carefully scoped remote-access and Docker-security checks.

> **If the plugin cannot explain and defend a finding, it should not report it as fact.**
