import uuid
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional

import numpy as np
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from src.backend.db import Database
from src.backend.models import Config, MediaItem
from src.backend.ollama_client import OllamaClient
from src.backend.pipeline import IngestionPipeline
from src.backend.search import SearchEngine

# ----------------------------------------------------------------
# Lifespan — initialise shared services on startup
# ----------------------------------------------------------------
config = Config()

db: Optional[Database] = None
ai: Optional[OllamaClient] = None
pipeline: Optional[IngestionPipeline] = None
search_engine: Optional[SearchEngine] = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global db, ai, pipeline, search_engine
    db = Database(config.DB_PATH)
    ai = OllamaClient(vision_model=config.VISION_MODEL, embed_model=config.EMBED_MODEL)
    pipeline = IngestionPipeline(db=db, ai=ai, config=config)
    search_engine = SearchEngine(db=db, ai=ai)
    yield
    db.close()


app = FastAPI(title="MediaTag API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ----------------------------------------------------------------
# Pydantic schemas
# ----------------------------------------------------------------


class MediaOut(BaseModel):
    id: str
    path: str
    type: str
    description: str
    tags: str

    @classmethod
    def from_item(cls, item: MediaItem) -> "MediaOut":
        return cls(id=item.id, path=item.path, type=item.type, description=item.description, tags=item.tags)


class SearchResult(BaseModel):
    score: float
    path: str
    filename: str
    description: str


class IngestResponse(BaseModel):
    message: str
    processed: int
    skipped: int


# ----------------------------------------------------------------
# Endpoints
# ----------------------------------------------------------------


@app.get("/")
async def root():
    return {"app": "MediaTag", "version": "0.1.0"}


@app.get("/media", response_model=list[MediaOut])
async def list_media():
    items = db.get_all_media()
    return [MediaOut.from_item(item) for item in items]


@app.get("/media/{media_id}", response_model=MediaOut)
async def get_media(media_id: str):
    items = db.get_all_media()
    for item in items:
        if item.id == media_id:
            return MediaOut.from_item(item)
    raise HTTPException(status_code=404, detail="Media not found")


@app.get("/search", response_model=list[SearchResult])
async def search(q: str = Query(..., description="Natural language query"),
                 top_k: int = Query(5, ge=1, le=50)):
    results = search_engine.search(q, top_k=top_k)
    return [
        SearchResult(score=score, path=path, filename=Path(path).name, description=desc[:200] + "...")
        for score, path, desc in results
    ]


@app.post("/ingest", response_model=IngestResponse)
async def ingest():
    images_dir = config.IMAGES_DIR
    if not images_dir.exists():
        raise HTTPException(status_code=404, detail=f"Images folder not found: {images_dir}")

    processed = 0
    skipped = 0

    for image_path in sorted(images_dir.iterdir()):
        if image_path.suffix.lower() not in config.IMAGE_EXTENSIONS:
            continue
        if db.media_exists(str(image_path)):
            skipped += 1
            continue
        try:
            description = ai.describe_image(str(image_path))
            embedding = ai.generate_embedding(description)
            embedding_blob = np.array(embedding, dtype=np.float32).tobytes()

            item = MediaItem(
                id=str(uuid.uuid4()),
                path=str(image_path),
                type=image_path.suffix.lower().strip("."),
                description=description,
                tags="",
                embedding=embedding_blob,
            )
            db.insert_media(item)
            processed += 1
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error processing {image_path.name}: {e}")

    return IngestResponse(message="Ingestion complete", processed=processed, skipped=skipped)
