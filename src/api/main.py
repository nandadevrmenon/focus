from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from src.backend.db import Database
from src.backend.models import Config, MediaItem
from src.backend.ollama_client import OllamaClient
from src.backend.pipeline import IngestionPipeline
from src.backend.progress import progress as ingest_progress
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
    thumbnail_path: str = ""

    @classmethod
    def from_item(cls, item: MediaItem) -> "MediaOut":
        return cls(
            id=item.id,
            path=item.path,
            type=item.type,
            description=item.description,
            tags=item.tags,
            thumbnail_path=item.thumbnail_path or "",
        )


class SearchResult(BaseModel):
    score: float
    path: str
    filename: str
    description: str
    thumbnail_path: str = ""


class IngestResponse(BaseModel):
    message: str
    processed: int
    skipped: int


class IngestPathsRequest(BaseModel):
    paths: list[str]


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
    thumb_map = {item.path: item.thumbnail_path for item in db.get_all_media()}
    return [
        SearchResult(
            score=score,
            path=path,
            filename=Path(path).name,
            description=desc[:200] + "...",
            thumbnail_path=thumb_map.get(path, ""),
        )
        for score, path, desc in results
    ]


@app.post("/ingest", response_model=IngestResponse)
async def ingest():
    from src.backend.pipeline import SUPPORTED_EXTENSIONS
    images_dir = config.IMAGES_DIR
    if not images_dir.exists():
        raise HTTPException(status_code=404, detail=f"Images folder not found: {images_dir}")

    paths = [p for p in sorted(images_dir.iterdir()) if p.suffix.lower() in SUPPORTED_EXTENSIONS]
    processed, skipped = pipeline.process_files(paths)
    return IngestResponse(message="Ingestion complete", processed=processed, skipped=skipped)


@app.post("/ingest-paths", response_model=IngestResponse)
async def ingest_paths(body: IngestPathsRequest):
    from src.backend.pipeline import SUPPORTED_EXTENSIONS

    valid_paths = []
    invalid = []
    for p in body.paths:
        path = Path(p)
        if not path.exists():
            invalid.append(f"{p}: not found")
            continue

        if path.is_dir():
            for child in sorted(path.rglob("*")):
                if child.suffix.lower() in SUPPORTED_EXTENSIONS:
                    valid_paths.append(child)
            continue

        if path.suffix.lower() not in SUPPORTED_EXTENSIONS:
            invalid.append(f"{path.name}: unsupported type (jpg/png only)")
            continue
        valid_paths.append(path)

    if not valid_paths:
        raise HTTPException(status_code=400, detail="; ".join(invalid) if invalid else "No valid files provided")

    processed, skipped = pipeline.process_files(valid_paths)
    msg = f"Ingestion complete. Processed: {processed}, Skipped: {skipped}"
    if invalid:
        msg += f". Errors: {'; '.join(invalid)}"
    return IngestResponse(message=msg, processed=processed, skipped=skipped)


@app.get("/ingest-status")
async def ingest_status():
    return {
        "is_processing": ingest_progress.is_processing,
        "total": ingest_progress.total,
        "completed": ingest_progress.completed,
        "current_file": ingest_progress.current_file,
    }
