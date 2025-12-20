<p align="center">
<img src="doc/assets/nocterm_banner.png" height="100" alt="Nocterm" />
</p>

[![CI](https://github.com/norbert515/nocterm/actions/workflows/ci.yml/badge.svg)](https://github.com/norbert515/nocterm/actions/workflows/ci.yml)
[![Pub Version](https://img.shields.io/pub/v/nocterm)](https://pub.dev/packages/nocterm)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**If you know Flutter, you know Nocterm.** Build terminal UIs with the same patterns—`StatefulComponent`, `setState()`, `Column`, `Row`, and hot reload.

![Nocterm Example](doc/assets/screenshot.png)

> **Note**: Nocterm is in early development (0.1.0). APIs may change.

## Installation

```yaml
dependencies:
  nocterm: ^0.1.0
```

## Quick Start

```dart
import 'package:nocterm/nocterm.dart';

void main() {
  runApp(const Counter());
}

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

Run with hot reload:

```bash
dart --enable-vm-service your_app.dart
```

## Inline Mode

For CLIs and tools that shouldn't take over the full screen, use inline mode:

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

## Documentation

See the [full documentation](https://docs.page/Norbert515/nocterm~docs) for guides on components, state management, testing, and more.

## Contributing

### Git Hooks

We use [hooksman](https://pub.dev/packages/hooksman) to manage git hooks. To install the hooks, run:

```bash
dart run hooksman
```

## License

MIT
