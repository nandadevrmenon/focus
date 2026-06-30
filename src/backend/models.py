from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


@dataclass
class Config:
    BASE_DIR: Path = Path(__file__).resolve().parent.parent.parent
    IMAGES_DIR: Path = BASE_DIR / "media"
    DB_PATH: Path = BASE_DIR / "media.db"
    THUMBS_DIR: Path = BASE_DIR / ".thumbs"
    VISION_MODEL: str = "moondream"
    EMBED_MODEL: str = "nomic-embed-text"
    IMAGE_EXTENSIONS: set = field(
        default_factory=lambda: {".jpg", ".jpeg", ".png", ".webp"}
    )


@dataclass
class MediaItem:
    id: str
    path: str
    type: str
    description: str
    tags: str
    embedding: Optional[bytes] = None
    thumbnail_path: str = ""
