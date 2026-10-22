FROM python:3.14-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /code

ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy

COPY pyproject.toml uv.lock ./

RUN uv sync --locked --no-install-project

COPY . .

CMD ["uv", "run", "--no-sync", "fastapi", "run", "main.py", "--port", "8000"]