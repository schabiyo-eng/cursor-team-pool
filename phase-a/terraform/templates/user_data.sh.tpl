#!/bin/bash
# Phase A Team Pool worker bootstrap.
# The service account key is read from Secrets Manager at process start.
# It is not written into this script, Terraform state, or a world-readable file.
# A download or install failure logs BOOTSTRAP FAILED and exits before the
# service is enabled or started.
set -euo pipefail

LOG=/var/log/cursor-pool-worker.log
touch "$LOG"
chmod 640 "$LOG"

log() {
  printf '%s\n' "$*" | tee -a "$LOG"
  printf '%s\n' "$*" >/dev/console || true
}

on_error() {
  local rc="$1"
  local line="$2"
  local cmd="$3"
  if [[ "$${BOOTSTRAP_FAILING:-0}" == "1" ]]; then
    exit "$rc"
  fi
  BOOTSTRAP_FAILING=1
  printf '%s\n' "BOOTSTRAP FAILED: $${cmd} (exit $${rc}) at line $${line}" | tee -a "$LOG" /dev/console || true
  exit "$rc"
}
trap 'on_error $? "$LINENO" "$BASH_COMMAND"' ERR

log "cursor pool worker bootstrap start"

sysctl -w net.ipv6.conf.all.disable_ipv6=1 || true
sysctl -w net.ipv6.conf.default.disable_ipv6=1 || true

if ! id cursor-worker >/dev/null 2>&1; then
  useradd --system --create-home --home-dir /var/lib/cursor-worker --shell /sbin/nologin cursor-worker
fi
install -d -o cursor-worker -g cursor-worker -m 0750 /var/lib/cursor-worker
install -d -o cursor-worker -g cursor-worker -m 0750 /var/lib/cursor-worker/work

# git has to be on PATH before the agent CLI. --clone-git-repos clones on claim.
git_installed=0
for attempt in 1 2 3 4 5; do
  if dnf install -y git 2>&1 | tee -a "$LOG" >(cat >>/dev/console || true); then
    git_installed=1
    break
  fi
  log "dnf install -y git failed (attempt $${attempt}/5); retrying in 2s"
  sleep 2
done
if [[ "$git_installed" != "1" ]] || ! command -v git >/dev/null 2>&1; then
  BOOTSTRAP_FAILING=1
  log "BOOTSTRAP FAILED: dnf install -y git failed after 5 attempts, or git is not on PATH. --clone-git-repos needs git. Check egress to the Amazon Linux repositories (TCP 443)."
  exit 1
fi
log "git on PATH: $(command -v git) ($(git --version))"

if [[ ! -x /var/lib/cursor-worker/.local/bin/agent ]]; then
  # tee keeps curl's "Failed to connect" line in the log and on the serial console.
  # A console write failure must not hide a successful install.
  if ! sudo -u cursor-worker env HOME=/var/lib/cursor-worker bash -c 'set -euo pipefail; curl -4fsSL --retry 5 --retry-delay 2 --retry-all-errors --connect-timeout 15 --max-time 180 https://cursor.com/install | bash' 2>&1 | tee -a "$LOG" >(cat >>/dev/console || true); then
    BOOTSTRAP_FAILING=1
    log "BOOTSTRAP FAILED: downloading or installing the worker from https://cursor.com/install (curl to cursor.com:443). Check egress: TCP 443 must be open, and a firewall allowlist must include cursor.com and downloads.cursor.com."
    exit 1
  fi
fi

if [[ ! -x /var/lib/cursor-worker/.local/bin/agent ]]; then
  BOOTSTRAP_FAILING=1
  log "BOOTSTRAP FAILED: agent binary was not installed at /var/lib/cursor-worker/.local/bin/agent"
  exit 1
fi

cat > /usr/local/bin/cursor-pool-worker << 'EOF'
#!/bin/bash
set -euo pipefail
secret="$(aws secretsmanager get-secret-value \
  --region "$CURSOR_POOL_AWS_REGION" \
  --secret-id "$CURSOR_POOL_SECRET_ID" \
  --query SecretString \
  --output text)"
# Strip surrounding whitespace and newlines. A trailing newline left by echo
# or a file redirect makes Cursor reject the key as invalid.
secret="$${secret#"$${secret%%[![:space:]]*}"}"
secret="$${secret%"$${secret##*[![:space:]]}"}"
if [[ -z "$secret" || "$secret" == "None" ]]; then
  echo "service account secret has no value yet" >&2
  exit 1
fi
if [[ "$secret" == *$'\n'* ]]; then
  echo "service account secret must be a single-line string" >&2
  exit 1
fi
export CURSOR_API_KEY="$secret"
unset secret
exec /var/lib/cursor-worker/.local/bin/agent worker \
  --pool "$CURSOR_POOL_NAME" \
  --worker-dir /var/lib/cursor-worker/work \
  --idle-release-timeout "$CURSOR_POOL_IDLE_TIMEOUT"%{ if clone_git_repos } \
  --clone-git-repos%{ endif } \
  start
EOF
chmod 755 /usr/local/bin/cursor-pool-worker

cat > /etc/systemd/system/cursor-pool-worker.service << EOF
[Unit]
Description=Cursor Team Pool worker (${pool_name})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=cursor-worker
Group=cursor-worker
Environment=HOME=/var/lib/cursor-worker
Environment=CURSOR_POOL_AWS_REGION=${aws_region}
Environment=CURSOR_POOL_SECRET_ID=${secret_id}
Environment=CURSOR_POOL_NAME=${pool_name}
Environment=CURSOR_POOL_IDLE_TIMEOUT=${idle_timeout}
WorkingDirectory=/var/lib/cursor-worker/work
ExecStart=/usr/local/bin/cursor-pool-worker
Restart=on-failure
RestartSec=20

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now cursor-pool-worker.service
log "cursor pool worker bootstrap done"
