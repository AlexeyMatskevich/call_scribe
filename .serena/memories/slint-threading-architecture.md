# Slint Threading Architecture

## Event Loop Model

Slint использует собственный event loop, который:
- Должен работать в main thread (на большинстве платформ)
- Блокирует поток при вызове `ui.run()`
- Обрабатывает: клики, перерисовку, таймеры, пользовательские события

## invoke_from_event_loop

Функция для безопасной передачи данных из любого потока в UI поток:

```rust
// Из любого потока:
slint::invoke_from_event_loop(move || {
    // Этот код выполнится в UI потоке
    // когда event loop его подхватит
}).ok();
```

**Как работает:**
- Thread-safe, можно вызывать из любого потока
- Добавляет функцию (замыкание) в очередь событий UI потока
- Event loop подхватывает и выполняет когда дойдёт очередь

**Типичный паттерн с Weak reference:**
```rust
let ui = MyWindow::new().unwrap();
let ui_weak = ui.as_weak();

std::thread::spawn(move || {
    let data = compute_something();
    let ui_weak_clone = ui_weak.clone();
    slint::invoke_from_event_loop(move || {
        if let Some(ui) = ui_weak_clone.upgrade() {
            ui.set_data(data);
        }
    }).ok();
});

ui.run().unwrap();
```

## spawn_local для async

Для интеграции с async/await внутри UI потока:
```rust
slint::spawn_local(async move {
    // async код здесь
}).unwrap();
```

## Ссылки
- https://docs.rs/slint/latest/slint/fn.invoke_from_event_loop.html
- https://docs.rs/slint/latest/slint/fn.spawn_local.html
