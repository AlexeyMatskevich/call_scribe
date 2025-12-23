# Slint UI Patterns and Pitfalls

**Read this memory when working with Slint UI in this project.**

## Vertical Alignment Issues

### Problem: Text appears higher than icons when both use `vertical-alignment: center`

Slint's `vertical-alignment: center` centers based on the text bounding box, but fonts have visual weight below the baseline (descenders for letters like "g", "y"). This causes text to appear slightly higher than icons when both use mathematical center.

### Solution: Add pixel offset to text positioning

Instead of:
```slint
Text {
    vertical-alignment: center;  // Text appears too high
}
```

Use absolute positioning with offset:
```slint
Text {
    x: (parent.width - self.width) / 2;
    y: (parent.height - self.height) / 2 + 1px;  // +1px or +2px offset
}
```

**Typical offsets:**
- Small text (12-14px): `+ 1px`
- Medium text (16-18px): `+ 2px`
- Large text (20px+): `+ 2px` to `+ 3px`

---

## Binding Loop Warnings

### Problem: Circular dependency when responsive layout depends on window width

This pattern creates a binding loop:
```slint
// BAD - creates binding loop
property <bool> is-collapsed: self.width < 900px;

HorizontalLayout {
    Sidebar {
        width: is-collapsed ? 64px : 256px;  // Width affects layout
    }
    // ... content
}
```

The loop: `window.width → is-collapsed → sidebar.width → layout.width → window.width`

### Solution: Use absolute positioning instead of layouts

```slint
// GOOD - no binding loop
property <bool> is-collapsed: root.width < Spacing.breakpoint-tablet;
property <length> current-sidebar-width: is-collapsed ? 64px : 256px;

// Sidebar with absolute position
Sidebar {
    x: 0;
    y: 0;
    height: 100%;
    is-collapsed: is-collapsed;
}

// Main content positioned after sidebar
Rectangle {
    x: current-sidebar-width;
    y: 0;
    width: root.width - current-sidebar-width;
    height: 100%;
    // ... content
}
```

**Key insight:** `root.width` (from Window) doesn't depend on child layouts, breaking the circular dependency.

---

## SVG Icon Issues

### Problem: Figma SVG exports use CSS variables that Slint doesn't support

Figma exports SVGs with:
```svg
<path stroke="var(--stroke-0, white)" />
```

Slint cannot parse CSS variables like `var()` or `currentColor`.

### Solution: Create clean SVGs with explicit colors

```svg
<svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path stroke="white" stroke-width="1.67" stroke-linecap="round" stroke-linejoin="round" d="..." />
</svg>
```

Then use Slint's `colorize` property to change the color dynamically:
```slint
Image {
    source: @image-url("icon.svg");
    colorize: active ? white : Theme.text-muted;
}
```

---

## Conditional Rendering

### Pattern: Show/hide elements based on state

```slint
// Conditional component rendering
if !is-collapsed: Text {
    text: "Label";
    // ... properties
}

// Conditional visibility (keeps element in tree)
Text {
    visible: !is-collapsed;
    text: "Label";
}
```

**Use `if condition:` when:**
- Element should not exist at all when hidden
- Layout should reflow without the element

**Use `visible:` when:**
- Element should maintain its space in layout
- Frequent toggling (slightly more performant)

---

## Named References for Property Access

### Problem: Accessing parent properties through layouts

```slint
// BAD - HorizontalLayout doesn't have custom properties
HorizontalLayout {
    property <bool> my-prop: true;
    
    Child {
        // parent.my-prop doesn't work!
    }
}
```

### Solution: Use named references

```slint
// GOOD - use := to name elements
container := Rectangle {
    property <bool> my-prop: true;
    
    HorizontalLayout {
        Child {
            some-prop: container.my-prop;  // Works!
        }
    }
}
```

---

## Animation Syntax

```slint
Rectangle {
    width: is-collapsed ? 64px : 256px;
    animate width { duration: 200ms; easing: ease-out; }
}
```

**Note:** Animations can contribute to binding loops if the animated property is part of layout calculations. Use with caution in responsive layouts.

---

## Button Accessibility Pattern

### Two layers required for full accessibility:

1. **Screen reader support** (`accessible-*` properties)
2. **Keyboard navigation** (`FocusScope` + `forward-focus`)

### Complete accessible button pattern:

```slint
export component MyButton inherits Rectangle {
    in property <string> text;
    callback clicked();

    // Screen reader accessibility
    accessible-role: button;
    accessible-label: text;
    accessible-action-default => { root.clicked(); }

    // Keyboard focus (Tab navigation)
    forward-focus: focus-scope;

    // Visual states
    background: touch.pressed ? Theme.button-pressed
              : touch.has-hover ? Theme.button-hover
              : Theme.button-default;
    animate background { duration: 150ms; }

    // Focus ring (visible when focused via Tab)
    border-width: focus-scope.has-focus ? 2px : 0px;
    border-color: Theme.primary;
    animate border-width { duration: 150ms; }

    // Keyboard handler (Enter/Space to click)
    focus-scope := FocusScope {
        key-pressed(event) => {
            if (event.text == Key.Return || event.text == " ") {
                root.clicked();
                accept
            }
            reject
        }
    }

    // Mouse/touch handler
    touch := TouchArea {
        clicked => { root.clicked(); }
    }
}
```

### For icon-only buttons:
Add an explicit label property since there's no text:
```slint
in property <string> accessible-text: "";
accessible-label: accessible-text;
```

---

## Hover States with TouchArea

### TouchArea provides three state properties:

```slint
touch := TouchArea {
    clicked => { /* click handler */ }
}

// Access states:
touch.pressed    // true while mouse button is held down
touch.has-hover  // true when mouse is over the element
touch.enabled    // whether touch area is active
```

### Ternary chain for visual states:

```slint
background: touch.pressed ? pressed-color
          : touch.has-hover ? hover-color
          : default-color;
```

---

## Data Structures vs Design Tokens

### Separation of concerns:

| File | Contains |
|------|----------|
| `tokens.slint` | Design values: Theme (colors), Spacing, Typography |
| `types.slint` | Data structures: NavItemData, etc. |
| `mod.slint` | Re-exports both |

### Import pattern:
```slint
import { Theme, Spacing, NavItemData } from "../shared/mod.slint";
```
