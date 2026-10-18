#!/usr/bin/env bash
# Runs inside the guest. Exercise the Docker paths CI needs without registration.
set -euo pipefail
test -f /var/lib/runner-provisioned
test "$(uname -m)" = x86_64
test -x /bin/bash
/home/runner/actions-runner/bin/Runner.Listener --version
docker compose version
docker buildx version
work=$(mktemp -d)
project="runner-smoke-$$"
trap 'docker compose -p "$project" -f "$work/compose.yml" down -v; docker image rm "$project:check"; rm -rf "$work"' EXIT
printf 'bind-mount-ok\n' > "$work/input"
cat > "$work/compose.yml" <<'EOF'
services:
  web:
    image: nginx:alpine
    healthcheck:
      test: [CMD, wget, -q, -O, /dev/null, 'http://127.0.0.1']
      interval: 2s
      timeout: 2s
      retries: 30
  check:
    image: alpine:3.21
    volumes:
      - ./input:/input:ro
    command: [sh, -ec, 'test "$$(cat /input)" = bind-mount-ok; wget -qO- http://web | grep -q "Welcome to nginx"']
EOF
printf 'FROM alpine:3.21\nRUN test -x /bin/sh\n' > "$work/Dockerfile"
docker buildx build --load -t "$project:check" "$work"
docker compose -p "$project" -f "$work/compose.yml" up -d --wait web
docker compose -p "$project" -f "$work/compose.yml" run --rm -T --interactive=false check
echo 'Runner VM smoke test passed.'
