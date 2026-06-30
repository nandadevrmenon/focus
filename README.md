# MediaTag

## Vision

MediaTag is a local-first macOS application that automatically indexes photos and videos stored on external SSDs, NAS drives, and local folders, transforming them into a searchable semantic media library.

Instead of manually browsing folders and filenames, users can search their media using natural language queries such as:

* "DJ crowd night vibe"
* "people eating food casually"
* "cinematic festival b-roll"
* "vertical Instagram clips"
* "energetic club footage"
* "sunset drone shots"
* "people laughing at dinner table"

The system understands the content of media rather than relying solely on filenames, folder structures, or manually assigned tags.

---

# Core Goals

## Local First

All processing should run locally on the user's machine.

Requirements:

* No cloud dependency
* No media uploaded to external services
* Works offline after installation
* User retains full ownership of data

---

## Automatic Media Understanding

The application should automatically analyze:

### Images

Generate:

* Descriptions
* Tags
* Scene classifications
* Mood classifications
* Embeddings for semantic search

Example:

Input:

```text
IMG_3244.jpg
```

Output:

```text
Description:
DJ performing in a crowded nightclub with colorful stage lighting.

Tags:
DJ, nightclub, crowd, nightlife, music, performance
```

---

### Videos

Automatically:

* Extract representative keyframes
* Analyze multiple frames
* Create clip-level summaries
* Generate tags
* Generate embeddings

Example:

```text
festival_aftermovie.mp4
```

Output:

```text
Description:
Crowd dancing at an outdoor electronic music festival during sunset.

Tags:
festival, crowd, dancing, sunset, electronic music, b-roll
```

---

# Semantic Search

The primary feature of MediaTag.

Users should be able to search naturally.

Examples:

```text
crowd enjoying music
```

```text
people eating outdoors
```

```text
vertical social media content
```

```text
nightclub footage
```

Results should be returned based on meaning, not exact keywords.

---

# Finder-Like Experience

The application should feel familiar to macOS users.

Goals:

* Folder navigation
* Thumbnail grid
* List view
* Quick preview
* Drag and drop support
* Open media directly in Finder

The user should not feel like they are using a database application.

The application should feel like an intelligent media browser layered on top of Finder.

---

# Folder Monitoring

Users should be able to:

* Select folders
* Select SSDs
* Select NAS locations
* Add multiple media libraries

The application should automatically:

* Detect new files
* Detect deleted files
* Detect modified files
* Process new media in the background

No manual re-indexing should be required.

---

# Background Processing

MediaTag should operate continuously in the background.

When new files appear:

```text
new video
      ↓
queued
      ↓
analyzed
      ↓
indexed
      ↓
searchable
```

Users should see indexing status and progress.

---

# Media Preview

Search results should display:

For images:

* Thumbnail
* Description
* Tags
* Folder location

For videos:

* Thumbnail
* Duration
* Preview frame
* Description
* Tags

Potential future features:

* Hover scrubbing
* Video preview playback
* Contact sheets

---

# Metadata Layer

MediaTag should build its own metadata layer.

Store:

* File path
* File hash
* Description
* Tags
* Embeddings
* Processing status
* Creation dates
* Media type

This metadata should remain independent from the original media files.

No modification of original assets.

---

# Technology Direction

## AI Processing

Local LLMs via Ollama.

Potential models:

### Vision

* Moondream
* Qwen2-VL
* Future vision models

### Embeddings

* nomic-embed-text
* BGE models
* Future embedding models

---

## Storage

Local SQLite database.

Stores:

* Metadata
* Processing state
* Search data

Potential future additions:

* sqlite-vec
* FAISS
* Other vector search engines

---

## Backend

Python

Responsible for:

* Folder scanning
* Video processing
* AI inference orchestration
* Embedding generation
* Search indexing
* Background jobs

Python acts as the application's intelligence layer.

---

## Frontend

Native macOS application in Swift/SwiftUI.

Responsible for:

* Folder selection
* Search interface
* Media browsing
* Preview generation
* Settings
* User experience

Swift acts as the presentation layer.

---

# Proposed Architecture

```text
                SwiftUI macOS App
                         │
                         │
                    Local API
                         │
                         ▼
               Python Processing Engine
                         │
     ┌───────────────────┼───────────────────┐
     │                   │                   │
     ▼                   ▼                   ▼

 Folder Scan      Vision Analysis      Search Engine
     │                   │                   │
     ▼                   ▼                   ▼

  SQLite          Embeddings          Vector Search
```

---

# MVP Scope

Version 1 should focus on:

* Folder selection
* Image ingestion
* Video ingestion
* Moondream caption generation
* Embedding generation
* SQLite storage
* Semantic search
* Basic search UI

No advanced editing features.

No cloud functionality.

No collaboration features.

No user accounts.

---

# Long-Term Vision

Become a local AI-powered media management tool that combines elements of:

* Finder
* Adobe Bridge
* Lightroom Library
* Spotlight Search

while remaining:

* local-first
* privacy-focused
* fast
* lightweight
* ownership-friendly

The user should be able to ask for media in plain English and immediately find the exact content they remember, regardless of where it is stored or how it was named.
