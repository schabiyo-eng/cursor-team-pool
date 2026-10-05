#!/bin/bash
# Phase A Team Pool worker bootstrap.
# The service account key is read from Secrets Manager at process start.
# It is not written into this script, Terraform state, or a world-readable file.
set -euo pipefail
exec > >(tee -a /var/log/cursor-pool-worker.log) 2>&1

echo "cursor pool worker bootstrap start"

sysctl -w net.ipv6.conf.all.disable_ipv6=1 || true
sysctl -w net.ipv6.conf.default.disable_ipv6=1 || true

if ! id cursor-worker >/dev/null 2>&1; then
  useradd --system --create-home --home-dir /var/lib/cursor-worker --shell /sbin/nologin cursor-worker
fi
install -d -o cursor-worker -g cursor-worker -m 0750 /var/lib/cursor-worker
install -d -o cursor-worker -g cursor-worker -m 0750 /var/lib/cursor-worker/work

if [[ ! -x /var/lib/cursor-worker/.local/bin/agent ]]; then
  sudo -u cursor-worker env HOME=/var/lib/cursor-worker bash -c 'curl -4fsSL https://cursor.com/install | bash'
fi

cat > /usr/local/bin/cursor-pool-worker << 'EOF'
#!/bin/bash
set -euo pipefail
secret="$(aws secretsmanager get-secret-value \
  --region "$CURSOR_POOL_AWS_REGION" \
  --secret-id "$CURSOR_POOL_SECRET_ID" \
  --query SecretString \
  --output text)"
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
  --idle-release-timeout "$CURSOR_POOL_IDLE_TIMEOUT" \
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
echo "cursor pool worker bootstrap done"
