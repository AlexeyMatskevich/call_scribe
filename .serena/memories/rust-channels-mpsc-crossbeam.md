# Rust Channels: std::sync::mpsc vs crossbeam

## std::sync::mpsc

**После Rust 1.67:** переписан на основе crossbeam, теперь достаточно производителен.

### Характеристики:
- Multi-producer, single-consumer (MPSC)
- Часть стандартной библиотеки (нет зависимостей)
- Блокирующий `recv()` — усыпляет поток через OS примитивы (futex)
- Неблокирующий `try_recv()` — возвращает сразу

```rust
use std::sync::mpsc;

let (tx, rx) = mpsc::channel();

// Отправка (можно клонировать tx для multi-producer)
tx.send(data).ok();

// Получение
let data = rx.recv().unwrap();           // блокирует
let data = rx.try_recv();                 // не блокирует
let data = rx.recv_timeout(duration);     // с таймаутом
```

## crossbeam-channel

### Характеристики:
- Multi-producer, multi-consumer (MPMC)
- Быстрее для некоторых паттернов
- `select!` макрос для ожидания нескольких каналов
- Bounded и unbounded варианты

```rust
use crossbeam_channel::{unbounded, bounded, select};

let (tx, rx) = unbounded();           // без лимита
let (tx, rx) = bounded(100);          // буфер на 100 элементов

// select! для нескольких каналов
select! {
    recv(rx1) -> msg => { /* обработка из rx1 */ }
    recv(rx2) -> msg => { /* обработка из rx2 */ }
    default(Duration::from_millis(100)) => { /* таймаут */ }
}
```

## Когда что использовать

| Сценарий | Рекомендация |
|----------|-------------|
| Простой single-consumer | `std::sync::mpsc` |
| Нужен multi-consumer | `crossbeam-channel` |
| Ожидание нескольких каналов | `crossbeam-channel` (select!) |
| Минимум зависимостей | `std::sync::mpsc` |

## Важно: НЕ "устарел"

**Миф:** "std::sync::mpsc устарел в пользу crossbeam"
**Реальность:** После Rust 1.67 внутренняя реализация использует алгоритмы из crossbeam, API остался MPSC для обратной совместимости.

## recv() vs try_recv() для Audio Manager

```rust
// ❌ recv() заблокирует — не сможем обрабатывать данные от CPAL
loop {
    match cmd_rx.recv() {  // спит здесь
        Ok(cmd) => handle(cmd),
        Err(_) => break,
    }
    // samples_rx никогда не проверится!
}

// ✅ try_recv() + sleep — можем обрабатывать оба канала
loop {
    // Проверяем команды
    if let Ok(cmd) = cmd_rx.try_recv() {
        handle(cmd);
    }
    
    // Проверяем данные от audio
    while let Ok(samples) = samples_rx.try_recv() {
        process(samples);
    }
    
    std::thread::sleep(Duration::from_millis(10));
}
```
