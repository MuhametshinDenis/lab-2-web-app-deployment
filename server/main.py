import psycopg2
import os
from psycopg2.extras import RealDictCursor
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, Response
from dotenv import load_dotenv


app = FastAPI()

load_dotenv()

database_username = os.getenv('DATABASE_USERNAME')
database_password = os.getenv('DATABASE_PASSWORD')
database_host = os.getenv('DATABASE_HOST')
database_port = int(os.getenv('DATABASE_PORT') or 5432)
database_name = os.getenv('DATABASE_NAME')

DB_CONFIG = {
    "host": database_host,
    "dbname": database_name,
    "user": database_username,
    "password": database_password,
    "port": database_port,
    "options": "-c timezone=UTC",
}


def db():
    return psycopg2.connect(**DB_CONFIG)


@app.on_event("startup")
def create_table():
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS todos (
                    id SERIAL PRIMARY KEY,
                    title VARCHAR(200) NOT NULL,
                    completed BOOLEAN NOT NULL DEFAULT FALSE,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
            """)
        conn.commit()
    finally:
        conn.close()


async def body_json(request: Request):
    try:
        data = await request.json()
    except Exception:
        return None
    return data if isinstance(data, dict) else None


def error(message, status_code=400):
    return JSONResponse({"error": message}, status_code=status_code)


def validate_title(data):
    title = data.get("title")
    if not isinstance(title, str) or not title.strip():
        return None, error("title must be a non-empty string")
    title = title.strip()
    if len(title) > 200:
        return None, error("title must be at most 200 characters")
    return title, None


@app.get("/api/todos")
def get_todos():
    conn = db()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT id, title, completed, created_at FROM todos ORDER BY id")
            return cur.fetchall()
    finally:
        conn.close()


@app.get("/api/todos/{todo_id}")
def get_todo(todo_id: int):
    conn = db()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT id, title, completed, created_at FROM todos WHERE id = %s",
                (todo_id,),
            )
            todo = cur.fetchone()
            if todo is None:
                return error("Todo not found", 404)
            return todo
    finally:
        conn.close()


@app.post("/api/todos", status_code=201)
async def create_todo(request: Request):
    data = await body_json(request)
    if data is None:
        return error("Request body must be a JSON object")

    title, validation_error = validate_title(data)
    if validation_error:
        return validation_error

    completed = data.get("completed", False)
    if not isinstance(completed, bool):
        return error("completed must be a boolean")

    conn = db()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                INSERT INTO todos (title, completed)
                VALUES (%s, %s)
                RETURNING id, title, completed, created_at
                """,
                (title, completed),
            )
            todo = cur.fetchone()
        conn.commit()
        return todo
    finally:
        conn.close()


@app.put("/api/todos/{todo_id}")
async def update_todo(todo_id: int, request: Request):
    data = await body_json(request)
    if data is None:
        return error("Request body must be a JSON object")

    title, validation_error = validate_title(data)
    if validation_error:
        return validation_error

    if "completed" not in data:
        return error("completed is required")
    completed = data["completed"]
    if not isinstance(completed, bool):
        return error("completed must be a boolean")

    conn = db()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                UPDATE todos
                SET title = %s, completed = %s
                WHERE id = %s
                RETURNING id, title, completed, created_at
                """,
                (title, completed, todo_id),
            )
            todo = cur.fetchone()
            if todo is None:
                return error("Todo not found", 404)
        conn.commit()
        return todo
    finally:
        conn.close()


@app.delete("/api/todos/{todo_id}", status_code=204)
def delete_todo(todo_id: int):
    conn = db()
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM todos WHERE id = %s", (todo_id,))
            if cur.rowcount == 0:
                return error("Todo not found", 404)
        conn.commit()
        return Response(status_code=204)
    finally:
        conn.close()
