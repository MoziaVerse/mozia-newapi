# Mozia deployment

New API (upstream: QuantumNous/new-api) is the customer gateway; Sub2API
(upstream: Wei-Shaw/sub2api) is its internal subscription-account upstream.
Both applications run code built from their respective `mozia` branches.
`main` tracks the original upstream and contains no deployment customizations.

The sibling server checkouts are `/opt/mozia/mozia-newapi` and
`/opt/mozia/mozia-sub2api`. Runtime secrets are outside Git, in
`/opt/mozia/secrets/stack.env` (root, mode 0600). Do not commit or print this
file, resolved Compose configuration, API keys, or bootstrap credentials.

## Operate

Run from this directory:

```sh
docker compose --env-file /opt/mozia/secrets/stack.env ps
docker compose --env-file /opt/mozia/secrets/stack.env up -d --no-build
```

Images use the source commit as their tag and an OCI revision label. New API's
`VERSION` build argument also records the commit in its UI/API version field;
the upstream repository's `VERSION` file is empty outside release builds. Builds
target `linux/arm64`. Build the applications sequentially on the 2-core VPS.
PostgreSQL 18 and Redis are separate for each service, with persistent volumes
and private data networks. No database or Redis port is published.

Sub2API uses its upstream-supported simple mode: account scheduling and API
authentication remain there; customer accounts and charging belong to New API.
Its management port is loopback-only, as is New API until HTTPS is configured.

```sh
ssh -N -L 13000:127.0.0.1:3000 -L 18080:127.0.0.1:8080 qiniu-sg
```

Open `http://localhost:13000` (New API) or `http://localhost:18080` (Sub2API).
After a domain resolves to this VPS, set `NEWAPI_DOMAIN`,
`NEWAPI_ORIGIN=https://<domain>` and `HTTPS_ENABLED=true` in the secret env file,
then use `docker compose --env-file /opt/mozia/secrets/stack.env --profile https up -d`.
Caddy obtains the certificate and forwards streaming responses without buffering.
Sub2API stays private and uses `http://sub2api:8080` as the New API channel base URL.
Use distinct channel credentials for OpenAI and Anthropic groups.

Import authorized upstream accounts in Sub2API before enabling customer traffic.
Verify each channel and its intended models and prices before accepting payment.
A healthy service or a working model listing does not prove upstream inference.

## Sync upstream and update

In a maintenance checkout of each fork (origin = MoziaVerse fork,
upstream = original repository), with a clean worktree:

```sh
git fetch origin
git fetch upstream
git switch main
git merge --ff-only origin/main
git merge --ff-only upstream/main
git push origin main
git switch mozia
git merge --ff-only origin/mozia
git merge main
# Resolve any conflicts, review and verify before pushing.
git push origin mozia
```

Never force-push `main` or overwrite the deployment branch with upstream.
On the server, fast-forward each `mozia` checkout, build fresh images tagged
with their commits, then update `NEWAPI_IMAGE`, `SUB2API_IMAGE` and
`NEWAPI_REVISION`, `SUB2API_REVISION` in the runtime env file and recreate the services.
Keep the previous images and take database backups before an upgrade.
Database migrations may prevent an image-only downgrade.

## Backup

Use `backup.sh` before upgrades. It writes PostgreSQL custom-format dumps and
a protected copy of the runtime secrets into `/opt/mozia/backups/<UTC timestamp>`.
Copy backups to separate storage for protection against loss of this VPS.
Backups and secrets must never enter Git. Redis is operational cache/state;
application-owned files live in the named data volumes and should also be
included in a full disaster-recovery backup.
