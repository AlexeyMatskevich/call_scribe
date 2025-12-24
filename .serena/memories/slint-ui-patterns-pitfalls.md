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

## Dynamic Color Manipulation for Hover States

### Problem: Hardcoded hover colors are hard to maintain

```slint
// BAD - hardcoded hex values
background: touch.pressed ? #d4d4d8 
          : touch.has-hover ? #e4e4e7 
          : #fafafa;
```

If you change the base color, you must manually recalculate hover/pressed colors.

### Solution: Use Slint's built-in color methods

Slint provides color manipulation methods:

| Method | Purpose | Example |
|--------|---------|---------|
| `color.darker(factor)` | Darken by factor (0.0-1.0) | `white.darker(0.15)` |
| `color.brighter(factor)` | Lighten by factor (0.0-1.0) | `#262626.brighter(0.3)` |
| `color.mix(other, factor)` | Blend two colors | `red.mix(blue, 0.5)` |
| `color.transparentize(factor)` | Add transparency | `blue.transparentize(0.3)` |
| `color.with-alpha(alpha)` | Set alpha channel | `red.with-alpha(0.8)` |

### Pattern: Base color with computed states

```slint
export component MyButton inherits Rectangle {
    // Define base color once
    property <color> base-color: #fafafa;
    
    // Compute states dynamically
    // darker(0.15) = 15% darker on hover
    // darker(0.25) = 25% darker on press
    background: touch.pressed ? base-color.darker(0.25)
              : touch.has-hover ? base-color.darker(0.15)
              : base-color;
    animate background { duration: 150ms; }
}
```

### Rule: darker() vs brighter()

| Background | Hover Effect | Method |
|------------|--------------|--------|
| Light (`#fafafa`, `white`) | Darken | `base-color.darker(0.15)` |
| Dark (`#262626`, `#18181b`) | Lighten | `base-color.brighter(0.3)` |

### Advanced: Configurable hover intensity

```slint
component ThemeCard inherits Rectangle {
    in property <color> card-background: white;
    in property <float> hover-darken: 0.1;  // Configurable intensity
    
    // Positive = darker (light backgrounds)
    // Negative = brighter (dark backgrounds)
    background: touch.pressed 
        ? (hover-darken >= 0 
            ? card-background.darker(hover-darken * 2)
            : card-background.brighter(-hover-darken * 2))
        : touch.has-hover 
            ? (hover-darken >= 0
                ? card-background.darker(hover-darken)
                : card-background.brighter(-hover-darken))
            : card-background;
}

// Usage:
ThemeCard { card-background: white; hover-darken: 0.12; }      // Light: 12% darker
ThemeCard { card-background: #18181b; hover-darken: -0.15; }   // Dark: 15% brighter
```

### Recommended hover intensities

| Element Type | Hover | Pressed |
|--------------|-------|---------|
| Light buttons | `darker(0.12-0.15)` | `darker(0.20-0.25)` |
| Dark buttons | `brighter(0.25-0.35)` | `brighter(0.40-0.50)` |
| Cards/panels | `darker(0.08-0.12)` | `darker(0.15-0.20)` |

### Benefits of this approach

1. **Single source of truth** — change base color, all states update automatically
2. **Consistent UX** — same percentage across similar components
3. **Self-documenting** — `darker(0.15)` is clearer than magic hex `#d4d4d8`
4. **Theme-friendly** — easy to switch between dark/light themes
5. **Maintainable** — no need to recalculate hex values manually

---

## Flickable Viewport Width

### Problem: Content overflows horizontally, text doesn't wrap

When using Flickable for vertical scrolling, if `viewport-width` is not set, the viewport takes the `preferred-width` of its content, which can be wider than the Flickable itself. This causes text with `wrap: word-wrap` to not wrap properly.

```slint
// BAD - content can overflow horizontally
Flickable {
    width: 100%;
    height: 100%;
    viewport-height: content.preferred-height;
    
    content := VerticalLayout {
        Text { wrap: word-wrap; }  // Won't wrap! Infinite width
    }
}
```

### Solution: Lock viewport-width to Flickable width

```slint
// GOOD - content constrained to Flickable width
Flickable {
    width: 100%;
    height: 100%;
    viewport-width: self.width;  // Lock horizontal width
    viewport-height: content.preferred-height;
    
    content := VerticalLayout {
        Text { wrap: word-wrap; }  // Now wraps correctly
    }
}
```

---

## Responsive Padding and Spacing

### Pattern: Different padding for mobile vs desktop

Use ternary expressions with `is-mobile` property to adjust padding:

```slint
export component MyPage inherits Rectangle {
    in property <bool> is-mobile: false;
    
    VerticalLayout {
        // 16px on mobile, 32px on desktop
        padding: root.is-mobile ? Spacing.lg : Spacing.xxl;
        spacing: root.is-mobile ? Spacing.lg : Spacing.xxl;
        
        // ... content
    }
}
```

### Responsive button: icon-only on mobile

```slint
// Icon centered on mobile, left-aligned with text on desktop
Image {
    x: root.is-mobile ? (parent.width - self.width) / 2 : 12px;
    // ...
}

Text {
    visible: !root.is-mobile;  // Hidden on mobile
    // ...
}

// Width: square on mobile, content-based on desktop
width: root.is-mobile ? 36px : 12px + icon + text + 12px;
```

---

## Conditional Rendering and Accessibility

### Problem: Each `if` block is independent

When using `if condition:` for different layouts (mobile/desktop), each block creates an independent component. They don't share FocusScope or accessibility properties.

```slint
// BAD - compact mode missing keyboard support
if is-compact: Rectangle {
    TouchArea { clicked => { ... } }  // Only mouse works!
}

if !is-compact: PrimaryButton {
    // Has full accessibility from PrimaryButton component
}
```

### Solution: Full accessibility in each conditional block

```slint
// GOOD - both modes have full accessibility
if is-compact: Rectangle {
    // Accessibility
    accessible-role: button;
    accessible-label: "Start Session";
    accessible-action-default => { root.clicked(); }
    
    // Visual states
    background: touch.pressed ? pressed : touch.has-hover ? hover : default;
    border-width: focus.has-focus ? 2px : 0px;
    
    // Keyboard support
    focus := FocusScope {
        key-pressed(event) => {
            if (event.text == Key.Return || event.text == " ") {
                root.clicked();
                accept
            }
            reject
        }
    }
    
    touch := TouchArea {
        clicked => { root.clicked(); }
    }
}

if !is-compact: PrimaryButton {
    // PrimaryButton already has full accessibility
    clicked => { root.clicked(); }
}
```

**Rule:** Every interactive element in every `if` block must have:
1. `accessible-role` and `accessible-label`
2. `FocusScope` with key handler
3. `TouchArea` for mouse/touch
4. Visual feedback (hover, pressed, focus ring)

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
