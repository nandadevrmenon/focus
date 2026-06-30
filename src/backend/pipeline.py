import uuid
import numpy as np
from pathlib import Path

from .models import Config, MediaItem
from .db import Database
from .ollama_client import OllamaClient


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

        for image_path in sorted(images_dir.iterdir()):
            if image_path.suffix.lower() not in self.config.IMAGE_EXTENSIONS:
                continue

            print(f"Processing: {image_path.name}")

            if self.db.media_exists(str(image_path)):
                print("  Already in DB, skipping.")
                continue

            self._process_file(image_path)

        print("Ingestion complete.")

    def _process_file(self, image_path: Path):
        try:
            description = self.ai.describe_image(str(image_path))
            print("  Description generated.")

            embedding = self.ai.generate_embedding(description)
            embedding_blob = np.array(embedding, dtype=np.float32).tobytes()
            print("  Embedding generated.")

            item = MediaItem(
                id=str(uuid.uuid4()),
                path=str(image_path),
                type=image_path.suffix.lower().strip("."),
                description=description,
                tags="",
                embedding=embedding_blob,
            )

            self.db.insert_media(item)
            print("  Saved to database.\n")

        except Exception as e:
            print(f"  Error: {e}\n")
