# Data Storage: SQLite + Vector Search

## Архитектура хранения для audio app

```
recordings/
├── 2024-01-15_14-30-00.opus   # сжатое аудио
├── 2024-01-15_15-00-00.opus
└── ...

data.db  (SQLite)
├── recordings
│   ├── id, filename, duration, sample_rate, created_at
├── transcriptions
│   ├── recording_id, text, language, confidence
├── transcription_words (для тайм-кодов)
│   ├── transcription_id, word, start_ms, end_ms
└── recordings_fts (FTS5 для текстового поиска)
```

## Почему файлы для аудио

- **Размер:** минута WAV (16-bit, 44.1kHz, stereo) ≈ 10 МБ
- **Совместимость:** WAV/FLAC/OPUS откроет любой плеер
- **Streaming:** seek на позицию в файле проще чем из blob

## SQLite FTS5 для текстового поиска

```sql
-- Создание FTS5 таблицы
CREATE VIRTUAL TABLE transcriptions_fts USING fts5(
    text,
    recording_id UNINDEXED
);

-- Поиск
SELECT * FROM transcriptions_fts 
WHERE transcriptions_fts MATCH 'kubernetes OR docker';
```

## sqlite-vec для векторного поиска

Extension для vector search, работает везде где SQLite.

### Установка в Rust:
```rust
use sqlite_vec::sqlite3_vec_init;
use rusqlite::{ffi::sqlite3_auto_extension, Connection};
use zerocopy::AsBytes;

unsafe {
    sqlite3_auto_extension(Some(std::mem::transmute(
        sqlite3_vec_init as *const ()
    )));
}

let db = Connection::open("data.db")?;
```

### Создание таблицы:
```sql
CREATE VIRTUAL TABLE transcription_embeddings USING vec0(
    embedding float[384]  -- размерность зависит от модели
);
```

### KNN поиск:
```sql
SELECT rowid, distance
FROM transcription_embeddings
WHERE embedding MATCH ?
ORDER BY distance
LIMIT 10;
```

### Производительность:
- Brute-force поиск
- Хорошо работает до ~1M векторов
- Поддерживает quantization для экономии памяти

## fastembed-rs для embeddings

Локальная генерация embeddings через ONNX:

```rust
use fastembed::{TextEmbedding, InitOptions, EmbeddingModel};

let model = TextEmbedding::try_new(
    InitOptions::new(EmbeddingModel::AllMiniLML6V2)
        .with_show_download_progress(true)
)?;

let documents = vec!["текст для embedding"];
let embeddings = model.embed(documents, None)?;
// embeddings[0].len() -> 384
```

**Модели:**
- `AllMiniLML6V2` — 384 dimensions, быстрая
- `BGESmallENV15` — качественнее
- Квантизованные версии: добавить `Q` к имени

## FTS5 vs Vector Search

| | FTS5 | Vector Search |
|---|------|---------------|
| Поиск | По словам | По смыслу |
| "kubernetes" | Найдёт точное слово | Найдёт и "оркестрация контейнеров" |
| Скорость | Очень быстро | Зависит от количества векторов |
| Требования | Только SQLite | + embedding model |

**Гибридный подход:** FTS5 для грубой фильтрации → Vector для reranking.

## Альтернативы

- **LanceDB** — embedded vector DB на Rust
- **libSQL** (Turso) — форк SQLite с встроенными vectors
- **SurrealDB** — multi-model, но для распределённых систем

Для локального desktop приложения SQLite + sqlite-vec — оптимальный выбор.
