import sqlite3
from pathlib import Path
from typing import Optional

from .models import MediaItem


class Database:
    def __init__(self, db_path: Path):
        self.db_path = db_path
        self.conn = sqlite3.connect(db_path)
        self.cur = self.conn.cursor()
        self._init_schema()

    def _init_schema(self):
        self.cur.execute("""
            CREATE TABLE IF NOT EXISTS media (
                id TEXT PRIMARY KEY,
                path TEXT,
                type TEXT,
                description TEXT,
                tags TEXT,
                embedding BLOB
            )
        """)
        self.conn.commit()

    def media_exists(self, path: str) -> bool:
        self.cur.execute("SELECT id FROM media WHERE path = ?", (path,))
        return self.cur.fetchone() is not None

    def insert_media(self, item: MediaItem):
        self.cur.execute(
            "INSERT INTO media (id, path, type, description, tags, embedding) VALUES (?, ?, ?, ?, ?, ?)",
            (item.id, item.path, item.type, item.description, item.tags, item.embedding),
        )
        self.conn.commit()

    def get_all_media(self) -> list[MediaItem]:
        self.cur.execute("SELECT id, path, type, description, tags, embedding FROM media")
        return [MediaItem(*row) for row in self.cur.fetchall()]

    def get_all_with_embeddings(self) -> list[MediaItem]:
        self.cur.execute(
            "SELECT id, path, type, description, tags, embedding FROM media WHERE embedding IS NOT NULL"
        )
        return [MediaItem(*row) for row in self.cur.fetchall()]

    def close(self):
        self.conn.close()
