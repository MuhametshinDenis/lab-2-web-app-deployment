#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# Настройки по умолчанию
# ============================================================

DEFAULT_APP_DIR="/opt/laba-2"
APP_DIR=""
ENV_FILE=""
COMPOSE_FILE=""

# ============================================================
# Вспомогательные функции
# ============================================================

info() {
    echo -e "\n==> $*"
}

error() {
    echo -e "\nОшибка: $*" >&2
    exit 1
}

prompt_default() {
    local prompt="$1"
    local default="$2"
    local value

    read -r -p "$prompt [$default]: " value
    printf '%s' "${value:-$default}"
}

# ============================================================
# Этап 1. Проверка окружения
# ============================================================

check_environment() {
    info "Проверка окружения"

    if [[ "$EUID" -ne 0 ]]; then
        error "Запусти скрипт от root: sudo bash install.sh"
    fi

    command -v docker >/dev/null 2>&1 \
        || error "Docker не установлен."

    docker compose version >/dev/null 2>&1 \
        || error "Docker Compose plugin не установлен."

    docker info >/dev/null 2>&1 \
        || error "Docker Engine недоступен. Проверь службу Docker."

    echo "Docker и Docker Compose доступны."
}

# ============================================================
# Этап 2. Выбор директории
# ============================================================

configure_directory() {
    info "Настройка директории приложения"

    APP_DIR="$(prompt_default 'Путь установки' "$DEFAULT_APP_DIR")"

    [[ "$APP_DIR" == /* ]] \
        || error "Укажи абсолютный путь, например /opt/laba-2."

    APP_DIR="${APP_DIR%/}"

    [[ -n "$APP_DIR" ]] || APP_DIR="/"

    [[ "$APP_DIR" != "/" ]] \
        || error "Нельзя использовать корневую директорию /."

    ENV_FILE="$APP_DIR/.env"
    COMPOSE_FILE="$APP_DIR/compose.yml"

    if [[ -e "$ENV_FILE" || -e "$COMPOSE_FILE" ]]; then
        error "В $APP_DIR уже существует .env или compose.yml. Установка остановлена, существующие файлы не изменены."
    fi

    mkdir -p "$APP_DIR"
    chmod 750 "$APP_DIR"

    echo "Директория: $APP_DIR"
}

# ============================================================
# Этап 3. Запрос параметров PostgreSQL
# ============================================================

configure_database() {
    local db_username
    local db_password
    local db_name
    local db_port
    local confirm_password

    info "Настройка PostgreSQL"

    db_username="$(prompt_default 'Имя пользователя БД' 'username')"
    [[ "$db_username" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] \
        || error "Имя пользователя может содержать только латинские буквы, цифры и _, но не начинаться с цифры."

    db_name="$(prompt_default 'Имя базы данных' 'postgres')"
    [[ "$db_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] \
        || error "Недопустимое имя базы данных."

    db_port="$(prompt_default 'Внутренний порт PostgreSQL' '5432')"
    [[ "$db_port" =~ ^[0-9]+$ ]] \
        && (( 10#$db_port >= 1 && 10#$db_port <= 65535 )) \
        || error "Порт должен быть числом от 1 до 65535."

    while true; do
        read -r -s -p "Пароль PostgreSQL: " db_password
        echo

        [[ -n "$db_password" ]] \
            || { echo "Пароль не должен быть пустым."; continue; }

        read -r -s -p "Повтори пароль: " confirm_password
        echo

        if [[ "$db_password" == "$confirm_password" ]]; then
            break
        fi

        echo "Пароли не совпадают. Попробуй ещё раз."
    done

    # Экранируем символы для одинарных кавычек в .env.
    local escaped_password="$db_password"
    escaped_password="${escaped_password//\\/\\\\}"
    escaped_password="${escaped_password//\'/\\\'}"

    cat > "$ENV_FILE" <<EOF
DATABASE_USERNAME=$db_username
DATABASE_PASSWORD='$escaped_password'
DATABASE_HOST=database
DATABASE_PORT=$db_port
DATABASE_NAME=$db_name
EOF

    chmod 600 "$ENV_FILE"

    unset db_password confirm_password escaped_password

    echo "Файл .env создан."
    echo "Пароль не выводится на экран."
}

# ============================================================
# Этап 4. Создание compose.yml
# ============================================================

create_compose() {
    info "Создание compose.yml"

    cat > "$COMPOSE_FILE" <<'YAML'
services:
  client:
    image: ghcr.io/muhametshindenis/client-app:latest
    restart: always
    ports:
      - "4173:80"
    networks:
      - laba-network

  server:
    image: ghcr.io/muhametshindenis/fastapi-app:latest
    restart: always
    env_file:
      - .env
    ports:
      - "8000:8000"
    depends_on:
      database:
        condition: service_healthy
    networks:
      - laba-network

  database:
    image: postgres:18
    restart: always
    environment:
      POSTGRES_USER: ${DATABASE_USERNAME}
      POSTGRES_PASSWORD: ${DATABASE_PASSWORD}
      POSTGRES_DB: ${DATABASE_NAME}
      DATABASE_PORT: ${DATABASE_PORT}
    command: ["postgres", "-p", "${DATABASE_PORT}"]
    volumes:
      - postgres-data:/var/lib/postgresql
    healthcheck:
      test:
        - CMD-SHELL
        - pg_isready -h 127.0.0.1 -p "$${DATABASE_PORT}" -U "$${POSTGRES_USER}" -d "$${POSTGRES_DB}"
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 10s
    networks:
      - laba-network

networks:
  laba-network:
    driver: bridge

volumes:
  postgres-data:
YAML

    chmod 640 "$COMPOSE_FILE"

    echo "Файл compose.yml создан."
}

# ============================================================
# Этап 5. Проверка конфигурации
# ============================================================

validate_compose() {
    info "Проверка конфигурации Docker Compose"

    cd "$APP_DIR"

    docker compose config -q \
        || error "Конфигурация Compose содержит ошибки."

    echo "Конфигурация корректна."
}

# ============================================================
# Этап 6. Загрузка образов
# ============================================================

pull_images() {
    info "Загрузка Docker-образов"

    cd "$APP_DIR"

    docker compose pull \
        || error "Не удалось загрузить образы. Проверь подключение к Docker Hub."
}

# ============================================================
# Этап 7. Запуск приложения
# ============================================================

start_application() {
    info "Запуск приложения"

    cd "$APP_DIR"

    docker compose up -d --remove-orphans \
        || error "Не удалось запустить приложение."

    echo
    docker compose ps
}

# ============================================================
# Этап 8. Итог
# ============================================================

show_result() {
    cat <<EOF

============================================================
Установка завершена!
============================================================

Директория: $APP_DIR

Файлы:
  $COMPOSE_FILE
  $ENV_FILE

Frontend:
  http://localhost:4173

Backend:
  http://localhost:8000

Swagger:
  http://localhost:8000/docs

Полезные команды:

  cd "$APP_DIR"

  docker compose ps
  docker compose logs -f
  docker compose pull
  docker compose up -d

Пароль БД сохранён в .env с правами доступа 600.
Данные PostgreSQL хранятся в Docker volume postgres-data.

============================================================
EOF
}

# ============================================================
# Основной процесс
# ============================================================

main() {
    check_environment
    configure_directory
    configure_database
    create_compose
    validate_compose
    pull_images
    start_application
    show_result
}

main "$@"