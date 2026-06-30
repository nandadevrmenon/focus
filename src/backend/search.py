import numpy as np
from pathlib import Path

from .db import Database
from .ollama_client import OllamaClient


class SearchEngine:
    def __init__(self, db: Database, ai: OllamaClient):
        self.db = db
        self.ai = ai

    def _cosine_similarity(self, a: np.ndarray, b: np.ndarray) -> float:
        return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))

    def search(self, query: str, top_k: int = 5) -> list[tuple[float, str, str]]:
        query_vec = np.array(self.ai.generate_embedding(query), dtype=np.float32)

        items = self.db.get_all_with_embeddings()
        results = []

        for item in items:
            vec = np.frombuffer(item.embedding, dtype=np.float32)
            score = self._cosine_similarity(query_vec, vec)
            results.append((score, item.path, item.description))

        results.sort(reverse=True)
        return results[:top_k]
