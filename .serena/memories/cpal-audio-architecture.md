# CPAL Audio Architecture

## Callback Model

CPAL использует callback-модель: ты передаёшь функцию, ОС вызывает её в своём audio-потоке.

**Ключевой момент:** Это НЕ обычный поток который ты контролируешь. ОС вызывает callback примерно каждые 10ms с новыми audio данными.

```rust
let stream = device.build_input_stream(
    &config,
    move |data: &[f32], _: &cpal::InputCallbackInfo| {
        // Этот код вызывается ОС в audio потоке
        // ~каждые 10ms
        // data — сэмплы с микрофона
    },
    |err| eprintln!("Error: {}", err),
    None,
)?;

stream.play()?;  // Запускает поток
```

## Управление потоком

### Start
```rust
let stream = device.build_input_stream(...)?;
stream.play()?;
```

### Pause (если поддерживается платформой)
```rust
stream.pause()?;  // Может не работать на всех платформах
```

### Stop
```rust
drop(stream);  // Drop освобождает ресурсы и останавливает
// или
stream = None;  // Если Option<Stream>
```

### Pause через флаг (надёжнее)
```rust
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

let is_paused = Arc::new(AtomicBool::new(false));
let is_paused_clone = is_paused.clone();

let stream = device.build_input_stream(
    &config,
    move |data: &[f32], _| {
        if !is_paused_clone.load(Ordering::SeqCst) {
            // Обрабатываем данные только если не на паузе
            tx.send(data.to_vec()).ok();
        }
    },
    |err| {},
    None,
)?;

// Для паузы:
is_paused.store(true, Ordering::SeqCst);
```

## Ограничения Audio Callback

В audio callback **нельзя**:
- Делать аллокации (malloc)
- Блокирующие операции (mutex, I/O)
- Долгие вычисления

**Можно:**
- Отправить данные через lock-free канал
- Читать/писать атомарные переменные
- Копировать данные в pre-allocated буфер

## Коммуникация с UI

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   UI Thread     │     │  Audio Manager   │     │  CPAL Callback  │
│   (Slint)       │     │    Thread        │     │  (OS thread)    │
│                 │     │                  │     │                 │
│  cmd_tx.send()──┼────►│  cmd_rx.recv()   │     │                 │
│                 │     │                  │     │                 │
│  invoke_from_   │◄────┼──отправляет──────┼─────┤  samples_tx     │
│  event_loop()   │     │  данные в UI     │     │  .send(data)    │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

## Поддерживаемые платформы

- Linux: ALSA, PulseAudio, JACK
- macOS: CoreAudio
- Windows: WASAPI, ASIO (feature flag)
- Web: WebAudio (WASM)
- Android, iOS: нативные API

## Ссылки
- https://docs.rs/cpal/latest/cpal/
- https://github.com/RustAudio/cpal
