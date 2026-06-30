from pathlib import Path

from .models import Config
from .db import Database
from .ollama_client import OllamaClient
from .pipeline import IngestionPipeline
from .search import SearchEngine


def run_search_loop(search_engine: SearchEngine):
    print("\n--- Search your images ---")
    while True:
        query = input("\nQuery (or 'quit'): ").strip()
        if query.lower() in {"quit", "q", "exit"}:
            break
        if not query:
            continue

        matches = search_engine.search(query)
        if not matches:
            print("No results found.")
            continue

        for i, (score, path, desc) in enumerate(matches, 1):
            print(f"\n#{i} [{score:.3f}] {Path(path).name}")
            print(f"  {desc[:200]}...")


def main():
    config = Config()

    db = Database(config.DB_PATH)
    ai = OllamaClient(
        vision_model=config.VISION_MODEL,
        embed_model=config.EMBED_MODEL,
    )

    pipeline = IngestionPipeline(db=db, ai=ai, config=config)
    pipeline.run()

    search_engine = SearchEngine(db=db, ai=ai)
    run_search_loop(search_engine)

    db.close()


if __name__ == "__main__":
    main()
