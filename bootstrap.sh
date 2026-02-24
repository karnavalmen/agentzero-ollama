#!/usr/bin/env bash
set -euo pipefail

# === Настройки (можеш да ги смениш при пускане) ===
OLLAMA_MODEL="${OLLAMA_MODEL:-huihui_ai/qwen3-vl-abliterated:8b}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
AGENTZERO_PORT="${AGENTZERO_PORT:-8080}"
# =================================================

need_root() {
  # На някои системи EUID може да не е сетнат, затова fallback към id -u
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Пусни го със sudo:"
    echo "  sudo bash bootstrap.sh"
    exit 1
  fi
}

install_docker_if_missing() {
  if command -v docker >/dev/null 2>&1; then
    echo "[OK] Docker вече е инсталиран"
    return
  fi

  echo "[..] Инсталирам Docker + Docker Compose..."

  apt-get update
  apt-get install -y ca-certificates curl gnupg

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  systemctl enable --now docker || true
  echo "[OK] Docker инсталиран"
}

need_root
install_docker_if_missing

echo "[..] Стартирам Ollama + Agent Zero..."
export OLLAMA_MODEL OLLAMA_PORT AGENTZERO_PORT

# docker compose ще вземе docker-compose.yml от текущата папка (repo-то)
docker compose up -d

echo "[..] Чакам Ollama да се вдигне..."
sleep 3

echo "[..] Тегля модела в Ollama: $OLLAMA_MODEL"
docker exec -it ollama ollama pull "$OLLAMA_MODEL"

echo
echo "[OK] Готово."
echo "Ollama API:  http://<POD_IP>:${OLLAMA_PORT}"
echo "Agent Zero:  http://<POD_IP>:${AGENTZERO_PORT}"
echo
echo "Проверки:"
echo "  docker ps"
echo "  docker logs -f ollama"
echo "  docker logs -f agent-zero"
echo "  curl http://127.0.0.1:${OLLAMA_PORT}/api/tags"