import ollama


class OllamaClient:
    def __init__(self, vision_model: str = "moondream", embed_model: str = "nomic-embed-text"):
        self.vision_model = vision_model
        self.embed_model = embed_model

    def describe_image(self, image_path: str) -> str:
        response = ollama.chat(
            model=self.vision_model,
            messages=[
                {
                    "role": "user",
                    "content": (
                        "Describe this image in detail. "
                        "Focus on people, activity, mood, setting, and visual style."
                    ),
                    "images": [image_path],
                }
            ],
        )
        return response["message"]["content"]

    def generate_embedding(self, text: str) -> list[float]:
        response = ollama.embeddings(model=self.embed_model, prompt=text)
        return response["embedding"]
