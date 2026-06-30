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
        self._migrate()

    def _init_schema(self):
        self.cur.execute("""
            CREATE TABLE IF NOT EXISTS media (
                id TEXT PRIMARY KEY,
                path TEXT,
                type TEXT,
                description TEXT,
                tags TEXT,
                embedding BLOB,
                thumbnail_path TEXT DEFAULT ''
            )
        """)
        self.conn.commit()

    def _migrate(self):
        # Add thumbnail_path if upgrading an old DB
        try:
            self.cur.execute("ALTER TABLE media ADD COLUMN thumbnail_path TEXT DEFAULT ''")
            self.conn.commit()
        except sqlite3.OperationalError:
            pass  # column already exists

    def media_exists(self, path: str) -> bool:
        self.cur.execute("SELECT id FROM media WHERE path = ?", (path,))
        return self.cur.fetchone() is not None

    def insert_media(self, item: MediaItem):
        self.cur.execute(
            "INSERT INTO media (id, path, type, description, tags, embedding, thumbnail_path) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (item.id, item.path, item.type, item.description, item.tags, item.embedding, item.thumbnail_path),
        )
        self.conn.commit()

    def get_all_media(self) -> list[MediaItem]:
        self.cur.execute("SELECT id, path, type, description, tags, embedding, thumbnail_path FROM media")
        return [MediaItem(*row) for row in self.cur.fetchall()]

    def get_all_with_embeddings(self) -> list[MediaItem]:
        self.cur.execute(
            "SELECT id, path, type, description, tags, embedding, thumbnail_path FROM media WHERE embedding IS NOT NULL"
        )
        return [MediaItem(*row) for row in self.cur.fetchall()]

    def close(self):
        self.conn.close()
