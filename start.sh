#!/bin/sh
# Start PocketBase (loopback only), create the admin on first boot through
# Tinykit's own /api/setup on a loopback-only server, then open the public port.
set -eu
cd /app

DATA=/app/pocketbase/pb_data
MARKER="$DATA/.setup_complete"
PB_ADDR=127.0.0.1:8091
SETUP_PORT=3999

export BODY_SIZE_LIMIT="${BODY_SIZE_LIMIT:-10M}"
# Behind Railway's proxy: take the scheme from X-Forwarded-Proto,
# so generated URLs use https.
export PROTOCOL_HEADER="${PROTOCOL_HEADER:-x-forwarded-proto}"

mkdir -p "$DATA"

pids=""
cleanup() {
	trap - TERM INT
	[ -n "$pids" ] && kill $pids 2>/dev/null || true
	wait 2>/dev/null || true
	exit 0
}
trap cleanup TERM INT

echo "[tinykit] starting PocketBase on $PB_ADDR"
./pocketbase/pocketbase serve --http="$PB_ADDR" &
PB_PID=$!
pids="$PB_PID"

i=0
until curl -fsS "http://$PB_ADDR/api/health" >/dev/null 2>&1; do
	i=$((i + 1))
	if [ "$i" -gt 60 ] || ! kill -0 "$PB_PID" 2>/dev/null; then
		echo "[tinykit] PocketBase did not start" >&2
		exit 1
	fi
	sleep 1
done
echo "[tinykit] PocketBase is ready"

if [ ! -f "$MARKER" ]; then
	ADMIN_EMAIL="${ADMIN_EMAIL:-}"
	ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
	if [ -z "$ADMIN_EMAIL" ] || [ ${#ADMIN_PASSWORD} -lt 8 ]; then
		echo "[tinykit] first boot needs ADMIN_EMAIL and an ADMIN_PASSWORD of 8+ characters." >&2
		echo "[tinykit] refusing to open the public setup page; set both variables and redeploy." >&2
		kill "$PB_PID" 2>/dev/null || true
		exit 1
	fi
	echo "[tinykit] first boot: creating the admin account for $ADMIN_EMAIL"
	HOST=127.0.0.1 PORT=$SETUP_PORT node build/index.js &
	SETUP_PID=$!
	pids="$PB_PID $SETUP_PID"
	i=0
	until curl -fsS "http://127.0.0.1:$SETUP_PORT/api/setup" >/dev/null 2>&1; do
		i=$((i + 1))
		if [ "$i" -gt 60 ] || ! kill -0 "$SETUP_PID" 2>/dev/null; then
			echo "[tinykit] setup server did not start" >&2
			exit 1
		fi
		sleep 1
	done
	body=$(node -e 'process.stdout.write(JSON.stringify({email:process.env.ADMIN_EMAIL,password:process.env.ADMIN_PASSWORD}))')
	out=$(curl -sS -X POST -H 'Content-Type: application/json' --data "$body" "http://127.0.0.1:$SETUP_PORT/api/setup" || true)
	kill "$SETUP_PID" 2>/dev/null || true
	wait "$SETUP_PID" 2>/dev/null || true
	pids="$PB_PID"
	case "$out" in
		*'"success":true'*) echo "[tinykit] admin account created" ;;
		*) echo "[tinykit] setup failed: $out" >&2; exit 1 ;;
	esac
	[ -f "$MARKER" ] || { echo "[tinykit] setup marker missing after setup" >&2; exit 1; }
fi

echo "[tinykit] starting Tinykit on 0.0.0.0:${PORT:-3000}"
HOST=0.0.0.0 PORT="${PORT:-3000}" node build/index.js &
NODE_PID=$!
pids="$PB_PID $NODE_PID"

# Exit (and let Railway restart us) as soon as either process stops.
while kill -0 "$PB_PID" 2>/dev/null && kill -0 "$NODE_PID" 2>/dev/null; do
	sleep 2
done
echo "[tinykit] a process exited; stopping" >&2
kill $pids 2>/dev/null || true
exit 1
