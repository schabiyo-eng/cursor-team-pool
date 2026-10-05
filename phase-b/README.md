# Phase B — controller and session tokens

Not implemented. Phase A leaves the service account API key on the worker, loaded at process start from Secrets Manager.

Phase B moves that key off the worker:

1. A controller runs `agent worker controller --spawn ./spawn.sh --pool <pool_name> --session-token`.
2. The controller holds the service account key (`CURSOR_API_KEY` or `--api-key`).
3. On each claim, Cursor mints a session token. The spawn hook receives `CURSOR_AUTH_TOKEN` for that claim only, and starts `agent worker --pool "$CURSOR_POOL" --auth-token-file /run/cursor/token start`.
4. The token ends when the claim ends. `--session-token` cannot be combined with `--warm-idle`, because warm workers start before a claim exists.

The spawn hook can start a process, a container, or a new EC2 instance. Scaling policy and the hook script belong in this phase when it is built.

See [Worker controller](https://cursor.com/docs/cloud-agent/self-hosted/pool#worker-controller) and [Session tokens](https://cursor.com/docs/cloud-agent/self-hosted/pool#session-tokens).
