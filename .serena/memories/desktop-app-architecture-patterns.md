# Desktop App Architecture Patterns (Slint + Audio)

## Core-Shell Architecture

Разделение на чистую бизнес-логику (Core) и "грязную" работу с внешним миром (Shell).

```
┌─────────────────────────────────────────────────────────┐
│                      Shell                              │
│  (всё что связано с внешним миром)                      │
│                                                         │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                 │
│  │   UI    │  │  Audio  │  │  Files  │  ...            │
│  │ (slint) │  │ (cpal)  │  │         │                 │
│  └────┬────┘  └────┬────┘  └────┬────┘                 │
│       │            │            │                       │
│       ▼            ▼            ▼                       │
│  ┌─────────────────────────────────────────────────┐   │
│  │              Message Bus                         │   │
│  │         (channels + commands)                    │   │
│  └─────────────────────────────────────────────────┘   │
│                       │                                 │
└───────────────────────┼─────────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────────┐
│                      Core                               │
│  (чистая бизнес-логика, без зависимостей)              │
│                                                         │
│  - AudioProcessor (анализ, гистограмма)                │
│  - Transcriber (транскрипция)                          │
│  - SearchIndex (поиск)                                 │
│  - Settings (конфигурация)                             │
└─────────────────────────────────────────────────────────┘
```

## Структура файлов

```
src/
├── main.rs
├── core/
│   ├── mod.rs
│   ├── audio_analysis.rs
│   ├── transcription.rs
│   └── settings.rs
├── shell/
│   ├── mod.rs
│   ├── audio/
│   │   ├── mod.rs
│   │   ├── recorder.rs
│   │   └── manager.rs
│   ├── ui/
│   │   ├── mod.rs
│   │   └── callbacks.rs
│   └── storage/
│       └── db.rs
└── messages.rs
```

## Command Pattern для межпоточной коммуникации

```rust
// messages.rs
pub enum Command {
    StartRecording,
    PauseRecording,
    ResumeRecording,
    StopRecording,
    SetInputDevice(String),
}

pub enum Event {
    RecordingStarted,
    RecordingStopped { duration: Duration },
    AudioLevels(Vec<f32>),
    Error(String),
}
```

## Audio Manager Thread Pattern

```rust
fn audio_manager_loop(
    cmd_rx: mpsc::Receiver<Command>,
    event_tx: mpsc::Sender<Event>,
    ui_handle: slint::Weak<MainWindow>,
) {
    let mut stream: Option<cpal::Stream> = None;
    let (samples_tx, samples_rx) = mpsc::channel();
    
    loop {
        // Неблокирующая проверка команд
        match cmd_rx.try_recv() {
            Ok(Command::StartRecording) => {
                stream = Some(create_stream(samples_tx.clone()));
            }
            Ok(Command::StopRecording) => {
                stream = None;
                break;
            }
            Err(TryRecvError::Empty) => {}
            Err(TryRecvError::Disconnected) => break,
            _ => {}
        }
        
        // Обработка данных от CPAL
        while let Ok(samples) = samples_rx.try_recv() {
            let levels = compute_levels(&samples);
            
            // Отправка в UI
            let ui = ui_handle.clone();
            slint::invoke_from_event_loop(move || {
                if let Some(ui) = ui.upgrade() {
                    ui.set_audio_levels(levels.into());
                }
            }).ok();
        }
        
        std::thread::sleep(Duration::from_millis(10));
    }
}
```

## Инициализация при старте

Каналы и потоки создаются сразу при старте — это дёшево:
- Канал — маленькая структура в памяти
- Спящий поток почти не потребляет CPU

```rust
fn main() {
    // Создаём инфраструктуру сразу
    let (cmd_tx, cmd_rx) = mpsc::channel();
    let (event_tx, event_rx) = mpsc::channel();
    
    let ui = MainWindow::new().unwrap();
    let ui_weak = ui.as_weak();
    
    // Запускаем Audio Manager сразу (будет ждать команд)
    std::thread::spawn(move || {
        audio_manager_loop(cmd_rx, event_tx, ui_weak);
    });
    
    // UI callbacks используют готовый канал
    let cmd_tx_clone = cmd_tx.clone();
    ui.on_start_clicked(move || {
        cmd_tx_clone.send(Command::StartRecording).ok();
    });
    
    ui.run().unwrap();
}
```

## Аналогия с Rails

| Rails | Desktop App |
|-------|-------------|
| Controller | Shell (UI callbacks, Audio Manager) |
| Model | Core (бизнес-логика) |
| Service Object | Отдельный поток с loop + channels |
| Background Job | То же самое по сути |
| Request/Response | Command/Event через channels |
