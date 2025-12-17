<p align="center">
<img src="doc/assets/nocterm_banner.png" height="100" alt="Nocterm" />
</p>

[![CI](https://img.shields.io/github/actions/workflow/status/norbert515/nocterm/ci.yml?style=for-the-badge&logo=github&label=CI)](https://github.com/norbert515/nocterm/actions/workflows/ci.yml) [![Pub Version](https://img.shields.io/pub/v/nocterm?style=for-the-badge&logo=dart&logoColor=white)](https://pub.dev/packages/nocterm) [![Pub Points](https://img.shields.io/pub/points/nocterm?style=for-the-badge&logo=dart&logoColor=white)](https://pub.dev/packages/nocterm/score) [![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)](LICENSE)

**If you know Flutter, you know Nocterm.**

<!-- TODO: Add animated GIF showing app in action -->

![Nocterm Example](doc/assets/screenshot.png)

> **Note**: Nocterm is in early development (0.1.0). APIs may change.

## Features

| | |
|---|---|
| 🎯 **Flutter Patterns** | `StatefulComponent`, `setState()`, `BuildContext`—all the patterns you know |
| ⚡ **Hot Reload** | Instant feedback while developing, just like Flutter |
| 📐 **Layouts** | `Column`, `Row`, `Stack`, `Expanded`, `Container`, `Padding` |
| ⌨️ **Input** | Full keyboard and mouse support |
| 🧪 **Testing** | Flutter-style testing framework with `pumpComponent` and `sendKey` |
| 📝 **Inline Mode** | Build CLIs that don't take over the screen |

## Quick Start

```yaml
dependencies:
  nocterm: ^0.1.0
```

```dart
import 'package:nocterm/nocterm.dart';

void main() => runApp(
  Center(child: Text('Hello, Terminal!')),
);
```

Run with hot reload:

```bash
dart --enable-vm-service your_app.dart
```

## Flutter Developers Feel at Home

The API is intentionally familiar:

```
Flutter                          Nocterm
─────────────────────────────    ─────────────────────────────
StatelessWidget                  StatelessComponent
StatefulWidget                   StatefulComponent
setState(() => ...)              setState(() => ...)
Column, Row, Stack               Column, Row, Stack
Container, Padding               Container, Padding
Expanded, Flexible               Expanded, Flexible
Navigator.push()                 Navigator.push()
```

A simple counter looks almost identical:

```dart
class Counter extends StatefulComponent {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  int _count = 0;

  @override
  Component build(BuildContext context) {
    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.space) {
          setState(() => _count++);
          return true;
        }
        return false;
      },
      child: Center(
        child: Text('Count: $_count'),
      ),
    );
  }
}
```

## Inline Mode

For CLIs and tools that shouldn't take over the full screen:

```dart
await runApp(MyComponent(), screenMode: ScreenMode.inline);
```

See the [inline mode documentation](https://docs.page/Norbert515/nocterm~docs/fundamentals/inline-mode) for details.

## Testing

Test your TUI components just like Flutter widgets:

```dart
await testNocterm('counter test', (tester) async {
  await tester.pumpComponent(Counter());
  await tester.sendKey(LogicalKey.space);

  expect(tester.terminalState, containsText('Count: 1'));
});
```

## Ecosystem

- [`nocterm_riverpod`](https://pub.dev/packages/nocterm_riverpod) — Riverpod state management integration
- [`nocterm_web`](https://pub.dev/packages/nocterm_web) — Web/browser support

## Documentation

See the [full documentation](https://docs.page/Norbert515/nocterm~docs) for guides on components, state management, testing, and more.

## Contributing

### Git Hooks

We use [hooksman](https://pub.dev/packages/hooksman) to manage git hooks:

```bash
dart run hooksman
```

## License

MIT
