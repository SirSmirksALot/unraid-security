#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCANNER="$REPO_ROOT/src/scripts/security-check.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/etc/ssh" "$TMP/boot/config/shares"

cat > "$TMP/etc/shadow" <<'DATA'
root::0:0:99999:7:::
DATA
cat > "$TMP/etc/ssh/sshd-effective" <<'DATA'
port 22
permitemptypasswords yes
passwordauthentication yes
DATA
cat > "$TMP/listeners.txt" <<'DATA'
LISTEN 0 128 0.0.0.0:23 0.0.0.0:* users:(("in.telnetd",pid=1,fd=3))
LISTEN 0 128 0.0.0.0:22 0.0.0.0:* users:(("sshd",pid=2,fd=3))
DATA
cat > "$TMP/boot/config/shares/media.cfg" <<'DATA'
shareExport="e"
shareSecurity="public"
shareExportNFS="e"
shareSecurityNFS="public"
DATA
cat > "$TMP/boot/config/shares/private.cfg" <<'DATA'
shareExport="e"
shareSecurity="private"
shareExportNFS="-"
shareSecurityNFS="private"
DATA
cat > "$TMP/boot/config/flash.cfg" <<'DATA'
flashExport="e"
flashSecurity="public"
DATA
cat > "$TMP/boot/config/ident.cfg" <<'DATA'
USE_SSL="no"
DATA
cat > "$TMP/etc/unraid-version" <<'DATA'
version="7.2.4"
DATA

BAD_JSON="$TMP/bad.json"
UNRAID_SECURITY_ROOT="$TMP" \
UNRAID_SECURITY_LISTENERS_FILE="$TMP/listeners.txt" \
UNRAID_SECURITY_SSHD_EFFECTIVE_FILE="$TMP/etc/ssh/sshd-effective" \
  "$SCANNER" > "$BAD_JSON"

python - "$BAD_JSON" <<'PY'
import json, sys
p=sys.argv[1]
data=json.load(open(p))
by_id={f['id']: f for f in data['findings']}
assert by_id['root-account']['status']=='fail'
assert by_id['telnet-listener']['status']=='fail'
assert by_id['ssh-empty-passwords']['status']=='fail'
assert by_id['ssh-password-auth']['status']=='warning'
assert by_id['public-smb-shares']['status']=='fail'
assert 'media' in by_id['public-smb-shares']['observed']
assert by_id['flash-share']['status']=='fail'
assert by_id['public-nfs-shares']['status']=='warning'
assert by_id['webgui-tls']['status']=='warning'
assert by_id['unraid-version']['observed']=='7.2.4'
PY

# Secure fixture
cat > "$TMP/etc/shadow" <<'DATA'
root:$6$examplehash:0:0:99999:7:::
DATA
cat > "$TMP/etc/ssh/sshd-effective" <<'DATA'
port 22
permitemptypasswords no
passwordauthentication no
DATA
cat > "$TMP/listeners.txt" <<'DATA'
LISTEN 0 128 127.0.0.1:443 0.0.0.0:* users:(("nginx",pid=4,fd=3))
DATA
cat > "$TMP/boot/config/shares/media.cfg" <<'DATA'
shareExport="e"
shareSecurity="private"
shareExportNFS="-"
shareSecurityNFS="private"
DATA
cat > "$TMP/boot/config/flash.cfg" <<'DATA'
flashExport="-"
flashSecurity="private"
DATA
cat > "$TMP/boot/config/ident.cfg" <<'DATA'
USE_SSL="yes"
DATA

GOOD_JSON="$TMP/good.json"
UNRAID_SECURITY_ROOT="$TMP" \
UNRAID_SECURITY_LISTENERS_FILE="$TMP/listeners.txt" \
UNRAID_SECURITY_SSHD_EFFECTIVE_FILE="$TMP/etc/ssh/sshd-effective" \
  "$SCANNER" > "$GOOD_JSON"

python - "$GOOD_JSON" <<'PY'
import json, sys
p=sys.argv[1]
data=json.load(open(p))
by_id={f['id']: f for f in data['findings']}
for key in ['root-account','telnet-listener','ftp-listener','ssh-listener','ssh-empty-passwords','ssh-password-auth','public-smb-shares','flash-share','public-nfs-shares','webgui-tls']:
    assert by_id[key]['status'] in ('pass','info'), (key, by_id[key])
assert by_id['webgui-tls']['status']=='pass'
assert by_id['flash-share']['status']=='pass'
PY

echo "All v1 scanner tests passed."
