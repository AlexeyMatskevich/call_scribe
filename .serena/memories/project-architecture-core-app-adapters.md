# Архитектура и структура проекта (Slint «frontend» + Rust «backend»)

## Документ: архитектурная модель (ментально “как Rails”) для Rust + Slint + CPAL (+ опционально SQLite/транскрибация)

### 0) Цель модели

Сделать структуру проекта:

* **предсказуемой** (как MVC в Rails: “я знаю, где это искать”),
* **расширяемой** (добавить БД/транскрибацию/новые экраны без переписываний),
* **безопасной по потокам** (Slint UI-thread, CPAL callback-thread),
* **с изоляцией «технического ада»** (buffers/channels/loops/build.rs) от бизнес-логики и UI-компонентов.

---

### 1) Ментальная карта “как Rails”

В Rails ты думаешь: **request → controller → model/service → render(view)**.

Здесь (GUI + аудио) — тот же паттерн, только “request” это **UI callback**, а “render” это **обновление Slint-состояния**:

* **`src/ui/` (Slint)** = *Views + component tree* (аналог `app/views` + front-end компоненты)
* **`src/presentation/` (Rust)** = *Controllers / UI glue* (принимает UI-сигналы, вызывает app-слой, “рендерит” в Slint-модели)
* **`src/app/` (Rust)** = *Use-cases / Service layer* (сценарии: Start/Pause/SetDevice/SaveSession…)
* **`src/domain/` (Rust)** = *Models* (но “Rails-like без ActiveRecord”: чистые типы и правила предметной области)
* **`src/services/` (Rust)** = *Adapters/Infra* (CPAL/SQLite/HTTP/Whisper/loops/buffers/channels)
* **`src/main.rs`** = *composition root* (как `config/application.rb` + initializers: собрать зависимости и запустить приложение)

Почему так удобно:

* `ui/` можно развивать как “React/FSD мир” без CPAL/DB.
* `domain/app` читаются как “чистая система” без потоков/буферов.
* `services` — единственное место, где разрешён “технический бойлерплейт”.

---

### 2) Потоки и границы ответственности (самое важное)

#### UI поток (Slint)

* Event loop **должен** работать в main thread (в большинстве backend-ов), и компоненты должны создаваться в том же потоке. ([Slint Docs][1])
* Из UI потока нельзя делать долгие операции: тяжёлый CPU/IO выносится наружу, а обратно в UI возвращается через `invoke_from_event_loop`, `Timer` или `spawn_local`. ([Slint Docs][1])

#### CPAL поток(и)

* CPAL вызывает data-callback из **dedicated high-priority thread** (или создаёт поток сам на платформах с blocking API). ([Docs.rs][2])
* Следствие: callback должен быть **минимальным** (никаких блокировок, аллокаций, IO, ожиданий). Это базовое realtime-правило. ([timur.audio][3])

---

### 3) Контракты: Command / Event как “HTTP request/response”

Чтобы проект не превратился в “паука из callback-ов”, фиксируем границу:

* **Command (UI → App)**: “намерение пользователя” (Start, Pause, Stop, SetDevice, ToggleTheme…)
* **Event (App/Services → UI)**: “что произошло/какое состояние теперь” (RecordingStarted, LevelMeterUpdated, TranscriptPartial, DeviceListChanged…)

Правило:

* UI **не знает** про CPAL/SQLite/транскрибацию.
* Services **не знают** про Slint модели.
* App слой координирует, но работает только с **портами (traits)**.

---

### 4) Структура репозитория (папки)

Ниже — структура, близкая к твоему черновику, но с уточнением “что где должно/не должно жить”.

```text
build.rs

src/
  main.rs                      # composition root: собрать реализации, запустить UI/event loop

  ui/                          # Slint frontend: только .slint + ассеты
    app.slint                  # entrypoint UI (как App.tsx)
    exports.slint              # (опционально) ре-экспорты наружу в Rust
    app/                       # shell, layout, навигация, провайдеры темы
    pages/                     # экраны (RecorderPage, SettingsPage, HistoryPage)
    widgets/                   # крупные блоки, композиция
    features/                  # действия пользователя (RecordControls, DevicePicker)
    entities/                  # визуализация сущностей (SessionRow, TranscriptItem)
    shared/
      components/              # Button, Modal, IconButton...
      tokens/                  # Colors/Spacing/Typo
      assets/                  # fonts/icons/images
      utils/                   # общие slint-функции/константы

  presentation/                # Rust UI glue: модели, биндинги, throttle/coalesce
    mod.rs
    generated.rs               # include_modules! + re-export окон/диалогов
    ui_shell.rs                # создание окна, wiring, таймеры UI
    bindings.rs                # on_* callbacks -> app::Command
    event_bridge.rs            # coalesce/throttle, invoke_from_event_loop helpers
    view_models/               # "что показывать": VM + mapping domain/app -> UI
    models/                    # VecModel/ModelRc подготовка и обновления (UI-thread only)

  app/                         # use-cases: сценарии и политики (без Slint/CPAL/SQLite)
    mod.rs
    commands.rs                # enum Command
    events.rs                  # enum Event
    state.rs                   # AppState (в памяти)
    orchestrator.rs            # обработка команд, вызовы портов, эмит событий
    ports/                     # traits: AudioPort/StoragePort/TranscriberPort/SettingsPort

  domain/                      # чистая логика и типы
    mod.rs
    settings.rs
    session.rs
    transcript.rs
    audio_metrics.rs
    errors.rs

  services/                    # инфраструктура: CPAL/SQLite/transcriber/threads/queues
    mod.rs

    audio/
      mod.rs
      api.rs                   # handle/commands/errors (то, что видит app)
      capture_cpal.rs          # CPAL device/stream/callback (минимум логики)
      engine.rs                # поток/loop: читает capture, раздаёт sink-ам
      buffers.rs               # ring/SPSC/очереди + политика переполнения
      sinks/                   # потребители (meter, file writer, transcriber)

    storage/
      mod.rs
      sqlite.rs                # конкретная реализация
      files.rs                 # (опционально) файлы/каталог сессий

    transcriber/
      mod.rs
      impl_local.rs
      impl_remote.rs
```

---

### 5) Чёткие правила “что где писать / что запрещено”

#### `src/ui/` (Slint)

**Пишем:**

* компоненты/страницы/виджеты,
* `property` для UI-состояния,
* `callback` для пользовательских действий,
* theme/tokens/fonts,
* локальные “UI-only” вычисления (layout, форматирование).

**Не пишем:**

* потоки, каналы, циклы обработки аудио,
* обращения к БД/сети,
* “бизнес-правила”.

Техническая причина: Slint рассчитан на то, что тяжёлую работу ты выносишь из main thread, а обратно возвращаешься через механизмы event loop. ([Slint Docs][1])

#### `src/presentation/` (Rust UI glue)

**Пишем:**

* создание `MainWindow::new()` и wiring callback-ов,
* хранение `ModelRc/VecModel` и обновление их **строго в UI thread**,
* перевод `app::Event` → обновления UI,
* throttle/coalesce (чтобы не пытаться перерисовать UI 500 раз/сек).

**Не пишем:**

* CPAL init/callback details,
* SQL/файловые транзакции,
* бизнес-решения (“можно ли сейчас стартовать запись”).

Причина: `ModelRc` **не `Send` и только для main thread**; обновления из других потоков делаются через `invoke_from_event_loop` или `Weak::upgrade_in_event_loop`. ([Slint Docs][4])

#### `src/app/` (Use-cases)

**Пишем:**

* обработку `Command`,
* состояние приложения (`AppState`) и правила переходов,
* вызовы портов (`AudioPort`, `StoragePort`, `TranscriberPort`),
* формирование `Event`.

**Не пишем:**

* Slint-типы/модели,
* CPAL callback/loop/buffers,
* SQL/SQLite детали.

#### `src/domain/`

**Пишем:**

* типы предметной области и чистые функции,
* ошибки и инварианты.

**Не пишем:**

* UI,
* CPAL/SQLite,
* потоки/каналы.

#### `src/services/`

**Пишем (и только тут это нормально):**

* threads, loops,
* каналы, очереди, backpressure,
* CPAL callback и устройство,
* sqlite соединения/миграции,
* интеграции транскрибатора.

**Не пишем:**

* Slint `ModelRc/VecModel` (они UI-thread only),
* доменную “политику” (это `app/`).

---

### 6) Slint: как устроить модули, exports и build.rs без боли

#### 6.1. Один entrypoint и никаких “регистраций компонентов”

Нормальная схема Slint:

* в `build.rs` компилируешь **один** главный `.slint` файл через `slint_build::compile(...)`,
* в Rust подключаешь сгенерированный код через `slint::include_modules!()`. ([Slint Docs][1])

Дальше UI дробится на файлы через `import/export` внутри Slint (модули). ([Slint Docs][5])
То есть проблема “надо регистрировать все компоненты” в правильной схеме отсутствует: ты “регистрируешь” только entrypoint.

#### 6.2. Ограничение `export * from ...` и как с ним жить

Slint поддерживает re-export, но `export * from "..."` **можно только один раз на файл**. ([Slint Docs][5])

Практический паттерн:

* сделай `ui/exports.slint`, где собираешь нужные наружу типы/глобалы;
* в `app.slint` сделай **один** `export * from "./exports.slint";`.

А если надо экспортировать из многих модулей — используй **точечные** ре-экспорты много раз:

```slint
export { MainWindow } from "./app/main_window.slint";
export { SettingsDialog } from "./app/settings_dialog.slint";
```

(это разрешено; ограничение именно про `export *`).

#### 6.3. Что экспортировать в Rust

* Экспортированные компоненты, которые наследуют `Window` или `Dialog`, генерируются как Rust-структуры, доступные там, где стоит `include_modules!()`/`slint!`. ([Slint Docs][1])
* Начиная с Slint 1.7 есть нормальная поддержка **нескольких экспортируемых окон/диалогов** (multi-window). ([Slint][6])

Правило практики:

* в Rust наружу обычно нужны **только окна/диалоги верхнего уровня** и иногда `export global`/`export struct/enum` для мостика типов.

#### 6.4. Где располагать `include_modules!()`

Удобно держать сгенерированное в `presentation/generated.rs`:

* чтобы UI glue всегда видел типы `MainWindow`, `SettingsDialog`,
* и чтобы `main.rs` не превращался в свалку.

---

### 7) Slint: данные, модели и потокобезопасность (архитектурное правило)

Ключевые факты:

* `ModelRc` **не `Send`**, его нельзя обновлять “с фонового потока напрямую”. ([Slint Docs][4])
* Обновления из worker thread возвращаются в UI через `invoke_from_event_loop` или `Weak::upgrade_in_event_loop`. ([Slint Docs][4])
* Для list/таблиц лучше мутировать модель и нотифицировать, чем постоянно “reset property”: это эффективнее и соответствует устройству `Model/ModelNotify`. ([Slint Docs][7])
* В callback-ах Slint/Rust нельзя захватывать strong-handle на компонент (получишь reference loop и утечку) — захватывай `Weak`. ([Slint Docs][1])

**Архитектурный вывод:**
`presentation/` — единственный слой, который трогает `ModelRc/VecModel`, и он делает это в UI thread.

---

### 8) Throttle / coalesce: стандартный механизм для GUI+аудио

Проблема: аудио/транскрибация генерируют события очень часто; UI столько не переварит.

Решение: в `presentation/event_bridge.rs` делаем “UI scheduler”:

**Вариант A (рекомендуемый): Timer-driven drain + coalesce**

* UI-thread `slint::Timer` тикает 16–33ms (60–30 FPS),
* на каждом тике неблокирующе “дренит” очередь событий и применяет **последнее** по каждому типу (latest wins).
  `Timer` нужно держать живым, иначе он остановится при drop. ([Docs.rs][8])

**Вариант B: push через invoke_from_event_loop**

* каждое событие из worker thread вызывает `invoke_from_event_loop`,
* но тогда coalesce нужно делать до вызова (иначе можно заспамить очередь UI). ([Docs.rs][9])

---

### 9) Services: как изолировать CPAL/loops/buffers и сделать универсально

#### 9.1. AudioService (CPAL) как “двухконтурная” система

Правило: CPAL callback — это “ISR-стиль”: быстро положил данные и вышел.

Рекомендуемая внутренняя архитектура `services/audio/`:

* `capture_cpal.rs`: только device/stream/callback, никаких аллокаций/локов/IO.
* `buffers.rs`: ring buffer / SPSC очередь + политика переполнения.
* `engine.rs`: один поток, который читает из буфера и делает fan-out в sink-и.
* `sinks/`: независимые потребители (meter/file/transcriber).
* `api.rs`: “ручка” наружу (`start/pause/stop/set_device/subscribe…`).

Причины:

* CPAL callback обычно идёт из high-priority потока. ([Docs.rs][2])
* На аудио-потоке нельзя делать ничего, что может блокировать/быть недетерминированным (mutex, syscalls, IO, аллокации). ([timur.audio][3])

#### 9.2. StorageService (SQLite/Files)

Делаем порт:

* `StoragePort`: `create_session`, `append_transcript`, `finalize_session`, `load_history`…
  Реализация:
* `services/storage/sqlite.rs` (sqlite)
* `services/storage/files.rs` (файлы) или `InMemoryStorage` (для ранней разработки)

App слой от этого не меняется.

#### 9.3. TranscriptionService

Делаем порт:

* `TranscriberPort`: `submit_audio_chunk`, `stop_session`…
  События наружу:
* `TranscriptPartial`, `TranscriptFinal`, `TranscriberError`

Реализация может быть:

* локальная,
* удалённая,
* гибридная — архитектура не ломается.

---

### 10) `global` в Slint: когда использовать

Есть два устойчивых паттерна:

**Паттерн 1: “Root callbacks”**
Все UI→Rust команды идут через top-level `MainWindow` callbacks.
Плюс: минимальная магия.
Минус: глубоко вложенным компонентам надо пробрасывать callbacks.

**Паттерн 2: `export global UiBridge`**
Команды/часть состояния доступны из любого компонента.
Плюс: удобно как “store”.
Минус: в multi-window важно помнить: global singletons **не шарятся между окнами**, их нужно инициализировать на каждом инстансе окна. ([Slint Docs][10])

Если ты хочешь максимально “Rails mental model” — `global UiBridge` часто ощущается как “ApplicationController helpers / global store”.

---

### 11) Мини-чеклист (быстрая самопроверка)

* `domain/` не знает про Slint/CPAL/SQLite.
* `app/` не знает про `ModelRc/VecModel`, не содержит loops/buffers.
* `presentation/` не знает про CPAL/SQLite детали.
* `services/` не трогает Slint-модели и UI handle-ы.
* `build.rs` компилирует **один** entrypoint `.slint`, остальное через `import`. ([Slint Docs][1])
* UI обновляется через coalesce/throttle (Timer или invoke queue), а не “каждый сэмпл → UI”.

---

## Обоснование: почему именно так (со ссылками на специфику Slint/CPAL)

### A) Почему `presentation/` обязателен как отдельный слой

1. Slint завязан на event loop и main thread:

* event loop обычно должен быть в main thread,
* компоненты создаются в том же потоке,
* тяжёлую работу надо выносить, а в UI возвращаться через `invoke_from_event_loop`/`Timer`/`spawn_local`. ([Slint Docs][1])

2. Slint модели не “обычные Rust структуры”:

* `ModelRc` не `Send`, обновлять из фоновых потоков напрямую нельзя. ([Slint Docs][4])
  Это автоматически диктует выделение места, где живут модели и где происходят UI-обновления: это и есть `presentation/`.

---

### B) Почему нужен Command/Event и коалесинг

Slint даёт “мостик” в UI thread, но не решает архитектурно вопрос частоты обновлений.
Как только появится аудио-метрика/partial transcript, поток событий легко превысит частоту кадров UI → получишь лаги.

Поэтому:

* App/Services публикуют события,
* Presentation “сжимает” их до частоты UI (throttle) и “последнее побеждает” (coalesce),
* и только потом трогает `ModelRc`.

---

### C) Почему CPAL надо изолировать в `services/audio/*`

CPAL прямо говорит, что callback вызывается в dedicated high-priority thread на современных платформах. ([Docs.rs][2])
В таком потоке любые блокировки/IO/аллокации и прочие недетерминированные вещи — риск глитчей. Это общая realtime-практика. ([timur.audio][3])

Отсюда архитектурное правило:

* callback только пишет в заранее подготовленную структуру (ring/SPSC),
* вся “умная” обработка — в обычном потоке `engine.rs`,
* fan-out в sink-и — тоже не из callback.

---

### D) Почему build.rs “один entrypoint” — правильная стратегия

Slint официально поддерживает схему: `slint_build::compile(main.slint)` + `slint::include_modules!()`, а разбиение делается через Slint-модули `import/export`. ([Slint Docs][1])
Это автоматически решает твою исходную боль “надо регистрировать каждый компонент”.

Дополнительно:

* `export * from "..."` ограничен: только один раз на файл, значит нужен “exports.slint” или точечные реэкспорты. ([Slint Docs][5])
* Multi-window и несколько экспортируемых окон/диалогов — поддерживаются (Slint 1.7+). ([Slint][6])

---

### E) Почему `global` надо использовать осознанно

Slint предупреждает: globals **не разделяются между окнами**; каждый экспортированный компонент имеет свой инстанс глобалов. ([Slint Docs][10])
Значит:

* либо ты делаешь один `MainWindow` и globals “как store”,
* либо при multi-window инициализируешь globals на каждом окне.

---

[1]: https://docs.slint.dev/latest/docs/rust/slint/ "slint - Rust"
[2]: https://docs.rs/cpal "cpal - Rust"
[3]: https://timur.audio/using-locks-in-real-time-audio-processing-safely "Using locks in real-time audio processing, safely – timur.audio"
[4]: https://docs.slint.dev/latest/docs/rust/slint/struct.ModelRc?utm_source=chatgpt.com "ModelRc in slint - Rust"
[5]: https://docs.slint.dev/latest/docs/slint/guide/language/coding/file/ "The `.slint` File | Slint Docs"
[6]: https://slint.dev/blog/slint-1.7-released "Slint 1.7 Released with New Widgets, Multi-Window Support, and Live-Preview Redesign — Slint Blog"
[7]: https://docs.slint.dev/latest/docs/rust/slint/trait.Model?utm_source=chatgpt.com "Model in slint - Rust"
[8]: https://docs.rs/slint/latest/slint/struct.Timer.html?utm_source=chatgpt.com "Timer in slint - Rust"
[9]: https://docs.rs/slint/latest/slint/fn.invoke_from_event_loop.html?utm_source=chatgpt.com "invoke_from_event_loop in slint - Rust"
[10]: https://docs.slint.dev/latest/docs/slint/guide/language/coding/globals/?utm_source=chatgpt.com "Globals"

App слой координирует, но работает только с портами (traits). - что это означает?

Это означает: **App слой (use-cases/orchestrator) не зависит от конкретных реализаций** (CPAL/SQLite/HTTP/threads), а зависит только от **абстракций**, которые он *сам определяет* как “порты” (**ports**). В Rust эти порты обычно оформляются как **traits**.

В терминах Hexagonal / Ports & Adapters:

* **Port** = интерфейс/контракт, через который “ядро приложения” общается с внешним миром.
* **Adapter** = конкретная реализация этого порта (например, `CpalAudioService`, `SqliteStorage`, `RemoteTranscriber`). ([Alistair Cockburn][1])
  В Clean Architecture это прямое применение Dependency Inversion: бизнес-логика и use-cases не зависят от UI/DB/frameworks. ([Clean Coder Blog][2])

### Как это выглядит в твоей структуре

`src/app/ports/` — место, где лежат traits, например:

* `AudioPort` — что app-слой *хочет* от аудио:

  * `start()`, `pause()`, `stop()`, `set_device(id)`, `list_devices()`, `subscribe_events()`
* `StoragePort` — что app-слой *хочет* от хранилища:

  * `create_session()`, `append_transcript()`, `load_history()`
* `TranscriberPort` — что app-слой *хочет* от транскрибатора:

  * `submit_chunk()`, `stop_session()`

`src/services/*` — реализации:

* `services/audio/*` **implements** `AudioPort`
* `services/storage/sqlite.rs` **implements** `StoragePort`
* `services/transcriber/*` **implements** `TranscriberPort`

`src/app/orchestrator.rs` — принимает зависимости как `dyn AudioPort`/`dyn StoragePort` или через generics и вызывает **только методы trait**, не зная, что там CPAL/SQLite.

### Мини-пример на Rust (идея)

```rust
// src/app/ports/audio.rs
pub trait AudioPort {
    fn start(&self) -> Result<(), AudioError>;
    fn stop(&self) -> Result<(), AudioError>;
    fn set_device(&self, id: String) -> Result<(), AudioError>;
}

// src/app/orchestrator.rs
pub struct Orchestrator<A: AudioPort> {
    audio: A,
}

impl<A: AudioPort> Orchestrator<A> {
    pub fn handle_start(&self) -> Result<(), AppError> {
        self.audio.start()?;
        Ok(())
    }
}
```

А в `services/audio/api.rs`:

```rust
pub struct CpalAudioService { /* channels, threads, etc */ }

impl AudioPort for CpalAudioService {
    fn start(&self) -> Result<(), AudioError> { /* ... */ Ok(()) }
    // ...
}
```

### Зачем это нужно (практический смысл)

1. **Меняешь реализацию без переписывания app-слоя**: сегодня CPAL, завтра другая библиотека — app не меняется. ([AWS Documentation][3])
2. **Тестируемость**: в тестах подставляешь `FakeAudioService`/`InMemoryStorage`, и сценарии use-case тестируются без UI/DB/audio. ([Clean Coder Blog][2])
3. **Изоляция технического кода**: loops/buffers остаются в `services/`, а app-слой остаётся коротким и читабельным.

### Важная деталь (частая ошибка)

Порт должен описывать **то, что нужно use-case’у**, а не то, “как устроен CPAL/SQLite”. Иначе инфраструктурные детали “протекут” внутрь app-слоя, и смысл портов пропадёт (это типичная проблема при неправильном DIP). ([Alistair Cockburn][1])

[1]: https://alistair.cockburn.us/hexagonal-architecture?utm_source=chatgpt.com "hexagonal-architecture - Alistair Cockburn"
[2]: https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html?utm_source=chatgpt.com "Clean Architecture by Uncle Bob - The Clean Code Blog"
[3]: https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/hexagonal-architecture.html?utm_source=chatgpt.com "Hexagonal architecture pattern - AWS Prescriptive Guidance"
