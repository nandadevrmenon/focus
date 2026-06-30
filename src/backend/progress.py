from dataclasses import dataclass, field


@dataclass
class IngestProgress:
    is_processing: bool = False
    total: int = 0
    completed: int = 0
    current_file: str = ""


progress = IngestProgress()
