#!/usr/bin/env bash

set -Eeuo pipefail

CONFIG_TARGET="/etc/nginx/conf.d/app.conf"
DEFAULT_SITE="/etc/nginx/sites-enabled/default"

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "Ошибка: запусти скрипт через sudo:"
        echo "sudo $0"
        exit 1
    fi
}

check_nginx() {
    if ! command -v nginx >/dev/null 2>&1; then
        echo "Ошибка: Nginx не установлен."
        exit 1
    fi
}

backup_config() {
    if [[ -f "$CONFIG_TARGET" ]]; then
        cp "$CONFIG_TARGET" "${CONFIG_TARGET}.bak"
        echo "Создана резервная копия: ${CONFIG_TARGET}.bak"
    fi
}

write_config() {
    mkdir -p "$(dirname "$CONFIG_TARGET")"

    cat > "$CONFIG_TARGET" <<'NGINX'
server {
    listen 80;
    listen [::]:80;

    server_name _;

    # FastAPI
    location /api/ {
        proxy_pass http://127.0.0.1:8000;

        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
    }

    # Frontend
    location / {
        proxy_pass http://127.0.0.1:4173;

        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
    }
}
NGINX

    echo "Конфигурация записана в $CONFIG_TARGET"
}

disable_default_site() {
    if [[ -L "$DEFAULT_SITE" ]]; then
        unlink "$DEFAULT_SITE"
        echo "Символическая ссылка default удалена."
    elif [[ -f "$DEFAULT_SITE" ]]; then
        mv "$DEFAULT_SITE" "${DEFAULT_SITE}.disabled"
        echo "Конфигурация default отключена."
    else
        echo "Активная конфигурация default не найдена."
    fi
}

validate_config() {
    echo
    echo "==> Проверка конфигурации Nginx"

    if nginx -t; then
        echo "Конфигурация корректна."
    else
        echo "Ошибка конфигурации Nginx."

        if [[ -f "${CONFIG_TARGET}.bak" ]]; then
            cp "${CONFIG_TARGET}.bak" "$CONFIG_TARGET"
            echo "Предыдущая конфигурация app.conf восстановлена."
        else
            rm -f "$CONFIG_TARGET"
            echo "Созданная конфигурация удалена."
        fi

        exit 1
    fi
}

restart_nginx() {
    echo
    echo "==> Применение конфигурации Nginx"

    if systemctl is-active --quiet nginx; then
        systemctl reload nginx
    else
        systemctl enable --now nginx
    fi

    echo "Nginx успешно настроен."
}

main() {
    echo
    echo "==> Настройка Nginx"

    check_root
    check_nginx
    backup_config
    write_config
    disable_default_site
    validate_config
    restart_nginx
}

main "$@"