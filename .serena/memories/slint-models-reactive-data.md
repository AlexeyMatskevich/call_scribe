# Slint Models: Реактивное связывание данных

## Концепция

`Model<T>` — trait-абстракция над коллекцией данных. UI автоматически перерисовывается когда модель изменяется (как реактивность в Vue/React).

## Основные типы моделей

### VecModel
Динамический массив с уведомлениями об изменениях:
```rust
use slint::{VecModel, Model};
use std::rc::Rc;

let model = Rc::new(VecModel::<MyStruct>::from(vec![...]));

// Операции:
model.push(item);              // добавить в конец
model.remove(index);           // удалить по индексу
model.set_row_data(i, data);   // обновить элемент (эффективно!)
model.row_count();             // количество элементов
model.row_data(i);             // получить элемент
```

### FilterModel
Фильтрация поверх другой модели:
```rust
use slint::FilterModel;

let filtered = Rc::new(FilterModel::new(
    base_model.clone(),
    |item| !item.completed  // предикат фильтрации
));
```

### SortModel
Сортировка поверх другой модели:
```rust
use slint::SortModel;

let sorted = Rc::new(SortModel::new(
    base_model.clone(),
    |a, b| a.name.cmp(&b.name)  // компаратор
));
```

## Привязка к UI

В .slint файле:
```slint
export struct TodoItem {
    title: string,
    completed: bool,
}

export component TodoApp inherits Window {
    in property <[TodoItem]> items;
    
    for item in items: Text {
        text: item.title;
    }
}
```

В Rust:
```rust
let model = Rc::new(VecModel::<TodoItem>::from(vec![...]));
ui.set_items(model.clone().into());
```

## Thread Safety

**Важно:** VecModel использует `Rc`, не `Arc` — НЕ thread-safe!

```rust
// ❌ Ошибка компиляции — VecModel не Send
std::thread::spawn(move || {
    model.set_row_data(0, data);
});

// ✅ Правильно — через invoke_from_event_loop
std::thread::spawn(move || {
    let model = model.clone();
    slint::invoke_from_event_loop(move || {
        model.set_row_data(0, data);
    }).ok();
});
```

## Преимущества над set_property(Vec)

| Аспект | `set_items(Vec)` | `VecModel::set_row_data` |
|--------|------------------|-------------------------|
| Передача данных | Весь массив | Только изменённый элемент |
| Аллокации | Новый Vec | In-place обновление |
| Перерисовка UI | Весь список | Только изменённые элементы |

## Когда использовать

- **Простые значения** (статус, счётчик) → обычные properties
- **Списки** (записи, треки) → VecModel
- **Фильтрация/сортировка** → FilterModel/SortModel
- **Частые обновления** (waveform, histogram) → VecModel + set_row_data
