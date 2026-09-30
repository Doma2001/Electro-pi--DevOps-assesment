import os
from typing import Any
from urllib.parse import quote

import psycopg
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

app = FastAPI(title="Cloud DevOps Assessment API", version="1.0.0")

allowed_origins = [
    origin.strip()
    for origin in os.getenv("ALLOWED_ORIGINS", "*").split(",")
    if origin.strip()
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


def database_url() -> str:
    explicit_url = os.getenv("DATABASE_URL")
    if explicit_url:
        return explicit_url

    user = os.getenv("DB_USER")
    password = os.getenv("DB_PASSWORD")
    host = os.getenv("DB_HOST")
    port = os.getenv("DB_PORT", "5432")
    name = os.getenv("DB_NAME")

    if not all([user, password, host, name]):
        raise RuntimeError("Database configuration is incomplete")

    encoded_user = quote(user, safe="")
    encoded_password = quote(password, safe="")
    return f"postgresql://{encoded_user}:{encoded_password}@{host}:{port}/{name}"


class Item(BaseModel):
    name: str = Field(min_length=1, max_length=100)


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


def get_connection() -> psycopg.Connection[Any]:
    return psycopg.connect(database_url())


def ensure_table() -> None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS items (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR(100) NOT NULL,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
                """
            )
        conn.commit()


@app.get("/api/items")
def list_items() -> list[dict[str, Any]]:
    try:
        ensure_table()
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT id, name, created_at FROM items ORDER BY id DESC")
                rows = cur.fetchall()
        return [
            {"id": row[0], "name": row[1], "created_at": row[2].isoformat()}
            for row in rows
        ]
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@app.post("/api/items", status_code=201)
def create_item(item: Item) -> dict[str, Any]:
    try:
        ensure_table()
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO items (name) VALUES (%s) RETURNING id, name, created_at",
                    (item.name,),
                )
                row = cur.fetchone()
            conn.commit()
        return {"id": row[0], "name": row[1], "created_at": row[2].isoformat()}
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
