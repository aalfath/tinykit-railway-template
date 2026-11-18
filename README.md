[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/tinykit-1?utm_medium=integration&utm_source=button&utm_campaign=tinykit)

# Tinykit on Railway

Railway template for [Tinykit](https://github.com/tinykit-studio/tinykit), the open-source agentic app builder (a self-hosted alternative to Lovable, v0 and Replit), with PocketBase built in.

## What it deploys

One service, **Tinykit**, built from this repo:

| | |
|---|---|
| Tinykit | **0.1.1**, upstream commit [`b4aea2b`](https://github.com/tinykit-studio/tinykit/commit/b4aea2b575dbb149f2c4b9b01f8f0603d7c23da1) (the "v0.1.1 maintenance" merge, 2026-11-08) |
| PocketBase | 0.23.4 (the version Tinykit pins), SHA-256 checked |
| Base image | `node:22.23.5-alpine3.24@sha256:1314fb30ec37592d5845e5a160d522c0e680972aa534549940b8d73bde88481a` |
| Volume | `/app/pocketbase/pb_data`: the database, uploads, built apps and settings |
| Health check | `/_pb/api/health` (answers only when both Tinykit and PocketBase are up) |

Tinykit publishes no container image, so the `Dockerfile` builds the upstream source at the pinned commit (and checks it), following upstream's own `deploy/docker/Dockerfile`.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `ADMIN_EMAIL` | *(you enter it)* | Email of the admin account created on first boot. The only prompt. |
| `ADMIN_PASSWORD` | `${{secret(24)}}` | Generated password for that account. Read it in the service's Variables tab. |
| `PORT` | `3000` | Port Tinykit listens on. |

On the first boot, `start.sh` runs Tinykit's own setup on a server bound to `127.0.0.1` and creates the admin from these two variables, before the public port opens. The public `/setup` page is never reachable by anyone else. After that the variables are no longer read: change the password in the PocketBase admin (`/_pb/_/`) or under Settings.

AI is optional. Add a provider key under `/tinykit/settings`, or set `LLM_PROVIDER`, `LLM_MODEL`, `LLM_API_KEY` (and `LLM_BASE_URL` for OpenAI-compatible servers) on the service.

## Updates

Every change to this repo's `main` branch (a new Tinykit commit, a new base image) shows up as an "update available" notice in the Railway projects deployed from this template. Read `CHANGELOG.md` before applying one. Back up the volume first; the data stays on it across updates.
