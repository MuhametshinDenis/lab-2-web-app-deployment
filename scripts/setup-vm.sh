#!/bin/bash

set -e

# Проверка запуска от root
check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "Запусти скрипт через sudo: sudo $0"
        exit 1
    fi
}

# Обновление системы
update_system() {
    echo "==> Обновление системы..."

    apt update
    apt upgrade -y
}

# Удаление конфликтующих пакетов Docker
remove_old_docker() {
    echo "==> Удаление старых пакетов Docker..."

    apt remove -y \
        docker.io \
        docker-compose \
        docker-compose-v2 \
        docker-doc \
        docker-buildx \
        podman-docker \
        containerd \
        runc || true
}

# Установка зависимостей
install_dependencies() {
    echo "==> Установка зависимостей..."

    apt install -y ca-certificates curl
}

# Подключение официального репозитория Docker
setup_docker_repository() {
    echo "==> Подключение репозитория Docker..."

    install -m 0755 -d /etc/apt/keyrings

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc

    chmod a+r /etc/apt/keyrings/docker.asc

    tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    apt update
}

# Установка Docker Engine и Docker Compose
install_docker() {
    echo "==> Установка Docker..."

    apt install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    systemctl enable --now docker
}

# Установка Nginx
install_nginx() {
    echo "==> Установка Nginx..."

    apt install -y nginx

    systemctl enable --now nginx
}

# Проверка установленных компонентов
verify_installation() {
    echo "==> Проверка установки..."

    docker --version
    docker compose version
    nginx -v

    echo
    echo "Статус сервисов:"
    systemctl --no-pager --full status docker nginx
}

# Основной сценарий установки
main() {
    check_root
    update_system
    remove_old_docker
    install_dependencies
    setup_docker_repository
    install_docker
    install_nginx
    verify_installation

    echo
    echo "Docker, Docker Compose и Nginx успешно установлены!"
}

main "$@"