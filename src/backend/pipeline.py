import uuid
import hashlib
import subprocess
import numpy as np
from pathlib import Path
from typing import Optional

from .models import Config, MediaItem
from .db import Database
from .ollama_client import OllamaClient
from .progress import progress

SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png"}
# ".mp4"  # TODO: future video support


def _generate_thumbnail(image_path: Path, thumbs_dir: Path, size: int = 300) -> Optional[str]:
    try:
        thumbs_dir.mkdir(parents=True, exist_ok=True)
        hash_name = hashlib.md5(str(image_path).encode()).hexdigest()
        thumb_path = thumbs_dir / f"{hash_name}.jpg"

        if thumb_path.exists():
            return str(thumb_path)

        subprocess.run(
            ["sips", "-Z", str(size), "-s", "format", "jpeg", "--out", str(thumb_path), str(image_path)],
            capture_output=True,
            check=True,
        )
        return str(thumb_path)
    except Exception as e:
        print(f"  Thumbnail error: {e}")
        return None


class IngestionPipeline:
    def __init__(self, db: Database, ai: OllamaClient, config: Config):
        self.db = db
        self.ai = ai
        self.config = config

    def run(self):
        images_dir = self.config.IMAGES_DIR
        if not images_dir.exists():
            raise FileNotFoundError(f"Images folder not found: {images_dir}")

        print(f"Scanning: {images_dir}\n")

        paths = [p for p in sorted(images_dir.iterdir())]
        return self.process_files(paths)

    def process_files(self, paths: list[Path]) -> tuple[int, int]:
        to_process = [p for p in paths if p.is_file() and p.suffix.lower() in SUPPORTED_EXTENSIONS and not self.db.media_exists(str(p))]

        progress.is_processing = True
        progress.total = len(to_process)
        progress.completed = 0
        progress.current_file = ""

        processed = 0
        skipped = 0

        for file_path in paths:
            if not file_path.is_file():
                continue
            if file_path.suffix.lower() not in SUPPORTED_EXTENSIONS:
                continue

            if self.db.media_exists(str(file_path)):
                skipped += 1
                progress.completed += 1
                continue

            progress.current_file = file_path.name
            self._process_file(file_path)
            processed += 1
            progress.completed += 1

        progress.is_processing = False
        progress.current_file = ""
        print(f"Ingestion complete. Processed: {processed}, Skipped: {skipped}")
        return processed, skipped

    def _process_file(self, image_path: Path):
        try:
            description = self.ai.describe_image(str(image_path))
            print("  Description generated.")

            embedding = self.ai.generate_embedding(description)
            embedding_blob = np.array(embedding, dtype=np.float32).tobytes()
            print("  Embedding generated.")

            thumb_path = _generate_thumbnail(image_path, self.config.THUMBS_DIR)
            if thumb_path:
                print(f"  Thumbnail saved.")

            item = MediaItem(
                id=str(uuid.uuid4()),
                path=str(image_path),
                type=image_path.suffix.lower().strip("."),
                description=description,
                tags="",
                embedding=embedding_blob,
                thumbnail_path=thumb_path or "",
            )

            self.db.insert_media(item)
            print("  Saved to database.\n")

        except Exception as e:
            print(f"  Error: {e}\n")
