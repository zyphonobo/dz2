#!/usr/bin/env bash
# Стек с нуля одной командой: bash deploy.sh <версия>
# Вариант 03, Никитенко Е. В.
set -euo pipefail
cd "$(dirname "$0")"

VERSION=${1:?укажите версию: bash deploy.sh 5.0}
PREFIX=nikitenko-03
PORT=8009
REGISTRY=localhost:6003
IMAGE=$REGISTRY/$PREFIX/probe:$VERSION

# 1. Режим Swarm: включить, если он выключен.
if [ "$(docker info --format '{{.Swarm.LocalNodeState}}')" != active ]; then
  docker swarm init --advertise-addr eth0
fi

# 2. Свой реестр: создать контейнер registry:2, если его ещё нет.
if ! docker ps -a --format '{{.Names}}' | grep -qx "$PREFIX-registry"; then
  docker run -d --restart unless-stopped --name "$PREFIX-registry" \
    -p 6003:5000 -v "$PREFIX-registry:/var/lib/registry" registry:2
else
  docker start "$PREFIX-registry" > /dev/null   # если был остановлен
fi
until curl -sf "$REGISTRY/v2/" > /dev/null; do sleep 1; done

# 3. Образ: собрать с версией $VERSION и отправить в реестр.
docker build --build-arg VERSION="$VERSION" -t "$IMAGE" .
docker push "$IMAGE"

# 4. Стек: развернуть stack.yaml, передав в него VERSION.
VERSION="$VERSION" docker stack deploy --detach=false -c stack.yaml "$PREFIX"

# 5. Дождаться ответа приложения, не дольше 90 секунд.
SECONDS=0
until curl -sf -m 2 "127.0.0.1:$PORT/notes" > /dev/null; do
  if [ $SECONDS -ge 90 ]; then echo "приложение не ответило за 90 секунд" >&2; exit 1; fi
  sleep 2
done
curl -s "127.0.0.1:$PORT/notes"; echo
