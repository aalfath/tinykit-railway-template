# Changelog

## 0.1.1-r1 (2026-11-18)

First release of this template.

- Tinykit 0.1.1 at upstream commit `b4aea2b575dbb149f2c4b9b01f8f0603d7c23da1`, PocketBase 0.23.4, on `node:22.23.5-alpine3.24` pinned by digest.
- Admin account created on first boot from `ADMIN_EMAIL` and a generated `ADMIN_PASSWORD`; the public setup page is never exposed.
- All state on one volume at `/app/pocketbase/pb_data`. Health check `/_pb/api/health`.
