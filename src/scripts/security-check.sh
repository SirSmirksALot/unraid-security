#!/bin/bash
set -u

VERSION="1.0.0"
ROOT="${UNRAID_SECURITY_ROOT:-}"

path() {
  local p="$1"
  if [[ -n "$ROOT" ]]; then
    printf '%s%s' "${ROOT%/}" "$p"
  else
    printf '%s' "$p"
  fi
}

SHADOW_FILE="${UNRAID_SECURITY_SHADOW_FILE:-$(path /etc/shadow)}"
SSHD_CONFIG="${UNRAID_SECURITY_SSHD_CONFIG:-$(path /etc/ssh/sshd_config)}"
SHARE_DIR="${UNRAID_SECURITY_SHARE_DIR:-$(path /boot/config/shares)}"
FLASH_CFG="${UNRAID_SECURITY_FLASH_CFG:-$(path /boot/config/flash.cfg)}"
IDENT_CFG="${UNRAID_SECURITY_IDENT_CFG:-$(path /boot/config/ident.cfg)}"
UNRAID_VERSION_FILE="${UNRAID_SECURITY_VERSION_FILE:-$(path /etc/unraid-version)}"
LISTENERS_FILE="${UNRAID_SECURITY_LISTENERS_FILE:-}"
SSHD_EFFECTIVE_FILE="${UNRAID_SECURITY_SSHD_EFFECTIVE_FILE:-}"

FINDINGS=()

json_escape() {
  local s="${1-}"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

add_finding() {
  local id="$1" category="$2" title="$3" status="$4" severity="$5" observed="$6" reason="$7" recommendation="$8"
  FINDINGS+=("{\"id\":\"$(json_escape "$id")\",\"category\":\"$(json_escape "$category")\",\"title\":\"$(json_escape "$title")\",\"status\":\"$(json_escape "$status")\",\"severity\":\"$(json_escape "$severity")\",\"observed\":\"$(json_escape "$observed")\",\"reason\":\"$(json_escape "$reason")\",\"recommendation\":\"$(json_escape "$recommendation")\"}")
}

cfg_value() {
  local file="$1" key="$2"
  [[ -r "$file" ]] || return 1
  awk -F= -v key="$key" '
    $1 == key {
      value=substr($0,index($0,"=")+1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (value ~ /^".*"$/) { sub(/^"/, "", value); sub(/"$/, "", value) }
      print value
      exit
    }
  ' "$file"
}

listeners() {
  if [[ -n "$LISTENERS_FILE" && -r "$LISTENERS_FILE" ]]; then
    cat "$LISTENERS_FILE"
  elif command -v ss >/dev/null 2>&1; then
    ss -H -lntp 2>/dev/null || true
  elif command -v netstat >/dev/null 2>&1; then
    netstat -lntp 2>/dev/null | tail -n +3 || true
  fi
}

port_listening() {
  local port="$1"
  listeners | grep -Eq "(^|[[:space:]])([^[:space:]]*):${port}([[:space:]]|$)"
}

sshd_effective() {
  if [[ -n "$SSHD_EFFECTIVE_FILE" && -r "$SSHD_EFFECTIVE_FILE" ]]; then
    cat "$SSHD_EFFECTIVE_FILE"
  elif command -v sshd >/dev/null 2>&1; then
    sshd -T 2>/dev/null || true
  elif [[ -r "$SSHD_CONFIG" ]]; then
    awk '
      /^[[:space:]]*#/ {next}
      NF >= 2 {key=tolower($1); $1=""; sub(/^[[:space:]]+/, ""); print key " " tolower($0)}
    ' "$SSHD_CONFIG"
  fi
}

sshd_value() {
  local key="$1"
  sshd_effective | awk -v key="$key" 'tolower($1)==tolower(key){print tolower($2); exit}'
}

# 1. Root account protection
if [[ ! -r "$SHADOW_FILE" ]]; then
  add_finding "root-account" "accounts" "Root account protection" "unknown" "high" "Could not read /etc/shadow" "The scanner could not determine whether the root account has password protection." "Review the root account under Users and ensure it is protected with a strong password or intentionally locked."
else
  root_hash="$(awk -F: '$1=="root"{print $2; exit}' "$SHADOW_FILE")"
  if [[ -z "$root_hash" ]]; then
    add_finding "root-account" "accounts" "Root account protection" "fail" "critical" "Root password field is empty" "An empty root password can allow administrative access without a password, depending on the authentication path." "Set a strong root password immediately."
  elif [[ "$root_hash" == '!'* || "$root_hash" == '*'* ]]; then
    add_finding "root-account" "accounts" "Root account protection" "pass" "none" "Root password authentication appears locked" "A locked password field prevents password-based authentication for the root account." "No action required unless the account was locked unintentionally."
  else
    add_finding "root-account" "accounts" "Root account protection" "pass" "none" "Root password hash is present" "The root account has a password hash. This check cannot determine password strength from the hash." "Use a unique, strong root password and do not reuse it elsewhere."
  fi
fi

# 2. Telnet
if port_listening 23; then
  add_finding "telnet-listener" "services" "Telnet service" "fail" "critical" "TCP port 23 is listening" "Telnet transmits credentials and session data without encryption." "Disable Telnet and use SSH for command-line administration."
else
  add_finding "telnet-listener" "services" "Telnet service" "pass" "none" "No TCP listener detected on port 23" "No Telnet listener was detected locally." "No action required."
fi

# 3. FTP
if port_listening 21; then
  add_finding "ftp-listener" "services" "FTP service" "warning" "high" "TCP port 21 is listening" "Traditional FTP does not encrypt credentials or file transfers." "Disable FTP unless it is explicitly required, and prefer an encrypted transfer method."
else
  add_finding "ftp-listener" "services" "FTP service" "pass" "none" "No TCP listener detected on port 21" "No traditional FTP listener was detected locally." "No action required."
fi

# 4-6. SSH
ssh_port="$(sshd_value port)"
[[ "$ssh_port" =~ ^[0-9]+$ ]] || ssh_port="22"
if port_listening "$ssh_port"; then
  add_finding "ssh-listener" "ssh" "SSH listener" "info" "info" "SSH is listening on TCP port $ssh_port" "A local SSH listener is not proof of Internet exposure, but it increases the services available on the server." "Keep SSH disabled when not needed, or restrict access to trusted networks and users."
else
  add_finding "ssh-listener" "ssh" "SSH listener" "pass" "none" "No SSH listener detected on configured port $ssh_port" "The scanner did not detect SSH listening on its configured port." "No action required."
fi

permit_empty="$(sshd_value permitemptypasswords)"
case "$permit_empty" in
  yes)
    add_finding "ssh-empty-passwords" "ssh" "SSH empty passwords" "fail" "critical" "PermitEmptyPasswords yes" "SSH is configured to allow accounts with empty passwords to authenticate." "Set PermitEmptyPasswords to no and ensure every interactive account is protected."
    ;;
  no)
    add_finding "ssh-empty-passwords" "ssh" "SSH empty passwords" "pass" "none" "PermitEmptyPasswords no" "SSH rejects empty-password authentication." "No action required."
    ;;
  *)
    add_finding "ssh-empty-passwords" "ssh" "SSH empty passwords" "unknown" "high" "Could not determine PermitEmptyPasswords" "The scanner could not determine the effective SSH setting." "Review the effective sshd configuration and ensure PermitEmptyPasswords is disabled."
    ;;
esac

password_auth="$(sshd_value passwordauthentication)"
case "$password_auth" in
  yes)
    add_finding "ssh-password-auth" "ssh" "SSH password authentication" "warning" "medium" "PasswordAuthentication yes" "Password authentication is valid on Unraid but exposes SSH to password guessing and stolen-password risk when reachable." "Prefer SSH keys where practical and restrict SSH reachability to trusted networks."
    ;;
  no)
    add_finding "ssh-password-auth" "ssh" "SSH password authentication" "pass" "none" "PasswordAuthentication no" "SSH password authentication is disabled." "No action required."
    ;;
  *)
    add_finding "ssh-password-auth" "ssh" "SSH password authentication" "unknown" "medium" "Could not determine PasswordAuthentication" "The scanner could not determine the effective SSH authentication setting." "Review the effective sshd configuration."
    ;;
esac

# 7. SMB user shares
public_smb=()
if [[ -d "$SHARE_DIR" ]]; then
  shopt -s nullglob
  for share_file in "$SHARE_DIR"/*.cfg; do
    export_mode="$(cfg_value "$share_file" shareExport || true)"
    security_mode="$(cfg_value "$share_file" shareSecurity || true)"
    if [[ "$export_mode" == e* && "$security_mode" == "public" ]]; then
      public_smb+=("$(basename "$share_file" .cfg)")
    fi
  done
  shopt -u nullglob
fi

if (( ${#public_smb[@]} > 0 )); then
  share_list="$(IFS=', '; echo "${public_smb[*]}")"
  add_finding "public-smb-shares" "shares" "Public writable SMB shares" "fail" "high" "$share_list" "Unraid Public SMB mode grants guest users full read/write access to an exported share." "Change sensitive shares to Secure or Private and grant access only to users who need it."
else
  add_finding "public-smb-shares" "shares" "Public writable SMB shares" "pass" "none" "No exported Public SMB user shares detected" "No user share configuration was found that combines SMB export with Public security mode." "No action required."
fi

# 8. Boot/flash SMB exposure
flash_export="$(cfg_value "$FLASH_CFG" flashExport || true)"
flash_security="$(cfg_value "$FLASH_CFG" flashSecurity || true)"
if [[ "$flash_export" == e* ]]; then
  case "$flash_security" in
    public)
      add_finding "flash-share" "shares" "Boot device share" "fail" "critical" "Flash share is exported with Public security" "Public SMB mode grants guest users full read/write access to the boot device, which contains Unraid configuration and sensitive data." "Disable the flash share, or change it to Private and grant access only to trusted users."
      ;;
    secure)
      add_finding "flash-share" "shares" "Boot device share" "warning" "high" "Flash share is exported with Secure security" "Secure mode still permits guest read access. The boot device contains configuration and other sensitive data." "Disable the flash share when not needed. If it must be shared, prefer Private access for trusted users."
      ;;
    private)
      add_finding "flash-share" "shares" "Boot device share" "warning" "medium" "Flash share is exported with Private security" "Even restricted network exposure increases the impact of a trusted-user credential compromise." "Disable the flash share when not needed; otherwise keep it Private and tightly restrict users."
      ;;
    *)
      add_finding "flash-share" "shares" "Boot device share" "warning" "high" "Flash share is exported${flash_security:+ with $flash_security security}" "The boot device is available over SMB, but the scanner could not classify the security mode reliably." "Review the flash share and disable network export unless it is required."
      ;;
  esac
else
  add_finding "flash-share" "shares" "Boot device share" "pass" "none" "Flash share is not exported over SMB" "The boot device is not exposed as an SMB share." "No action required."
fi

# 9. NFS exports
public_nfs=()
if [[ -d "$SHARE_DIR" ]]; then
  shopt -s nullglob
  for share_file in "$SHARE_DIR"/*.cfg; do
    export_mode="$(cfg_value "$share_file" shareExportNFS || true)"
    security_mode="$(cfg_value "$share_file" shareSecurityNFS || true)"
    if [[ "$export_mode" == e* && "$security_mode" == "public" ]]; then
      public_nfs+=("$(basename "$share_file" .cfg)")
    fi
  done
  shopt -u nullglob
fi

if (( ${#public_nfs[@]} > 0 )); then
  nfs_list="$(IFS=', '; echo "${public_nfs[*]}")"
  add_finding "public-nfs-shares" "shares" "Public NFS exports" "warning" "high" "$nfs_list" "Public NFS exports can make data broadly available to systems permitted by the export configuration." "Restrict NFS exports to trusted hosts/networks and use the narrowest access mode that meets the need."
else
  add_finding "public-nfs-shares" "shares" "Public NFS exports" "pass" "none" "No Public NFS user-share exports detected" "No user share configuration was found that combines NFS export with Public security mode." "No action required."
fi

# 10. WebGUI HTTPS/TLS
use_ssl="$(cfg_value "$IDENT_CFG" USE_SSL || true)"
case "${use_ssl,,}" in
  yes|strict|auto)
    add_finding "webgui-tls" "webgui" "WebGUI TLS" "pass" "none" "USE_SSL=${use_ssl}" "Unraid is configured to use TLS for WebGUI access according to the local management setting." "No action required."
    ;;
  no|"")
    add_finding "webgui-tls" "webgui" "WebGUI TLS" "warning" "medium" "USE_SSL=${use_ssl:-not set}" "Primary WebGUI access may use unencrypted HTTP, allowing credentials and session data to be exposed on an untrusted network." "Enable SSL/TLS under Settings → Management Access when practical."
    ;;
  *)
    add_finding "webgui-tls" "webgui" "WebGUI TLS" "unknown" "medium" "USE_SSL=${use_ssl}" "The scanner does not recognize this TLS mode." "Review Settings → Management Access and verify that WebGUI traffic is encrypted."
    ;;
esac

# 11. Local management listeners summary
mgmt_lines="$(listeners | grep -E ':(22|23|80|443)([[:space:]]|$)' | head -n 8 || true)"
if [[ -n "$mgmt_lines" ]]; then
  add_finding "management-listeners" "network" "Management listeners" "info" "info" "$mgmt_lines" "These are local listeners only. They do not prove that any service is reachable from the public Internet." "Review router port-forwarding, UPnP, reverse proxies, and remote-access settings separately."
else
  add_finding "management-listeners" "network" "Management listeners" "info" "info" "No common management ports detected in local listener output" "This check only summarizes common local management listeners." "No action required."
fi

# 12. Installed Unraid version
unraid_version=""
if [[ -r "$UNRAID_VERSION_FILE" ]]; then
  unraid_version="$(cfg_value "$UNRAID_VERSION_FILE" version || true)"
  [[ -n "$unraid_version" ]] || unraid_version="$(grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?[^[:space:]]*' "$UNRAID_VERSION_FILE" | head -n 1 || true)"
fi
if [[ -n "$unraid_version" ]]; then
  add_finding "unraid-version" "updates" "Installed Unraid version" "info" "info" "$unraid_version" "This v1 scanner reports the installed version but does not contact Unraid to determine whether an update is available." "Use Tools → Update OS to check for supported updates and review release notes before upgrading."
else
  add_finding "unraid-version" "updates" "Installed Unraid version" "unknown" "info" "Could not determine installed Unraid version" "The version file was unavailable or did not contain a recognizable version." "Check /etc/unraid-version or Tools → Update OS."
fi

# Output
printf '{"scanner_version":"%s","generated_at":"%s","findings":[' "$VERSION" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
for i in "${!FINDINGS[@]}"; do
  (( i > 0 )) && printf ','
  printf '%s' "${FINDINGS[$i]}"
done
printf ']}\n'
