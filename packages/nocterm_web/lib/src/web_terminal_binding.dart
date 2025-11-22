import 'dart:async';
import 'dart:convert';

import 'package:xterm/xterm.dart' as xterm;
import 'package:nocterm/nocterm.dart';
import 'package:nocterm/src/keyboard/input_parser.dart';
import 'package:nocterm/src/keyboard/input_event.dart';
import 'package:nocterm/src/framework/terminal_canvas.dart';
import 'package:nocterm/src/buffer.dart' as buf;
import 'web_terminal.dart';

/// Terminal UI binding for web that handles terminal input/output via xterm.js
///
/// This is a simplified binding that integrates xterm.js with nocterm's rendering system.
class WebTerminalBinding extends NoctermBinding with SchedulerBinding {
  final WebTerminal terminal;
  final xterm.Terminal xterminal;

  PipelineOwner? _pipelineOwner;
  PipelineOwner get pipelineOwner => _pipelineOwner!;

  final _inputParser = InputParser();
  final _keyboardEventController = StreamController<KeyboardEvent>.broadcast();
  final _mouseEventController = StreamController<MouseEvent>.broadcast();

  WebTerminalBinding(this.terminal, this.xterminal) {
    _initializePipelineOwner();
  }

  void _initializePipelineOwner() {
    _pipelineOwner = PipelineOwner();
    _pipelineOwner!.onNeedsVisualUpdate = scheduleFrame;
  }

  void initialize() {
    // Setup terminal
    terminal.enterAlternateScreen();
    terminal.hideCursor();
    terminal.clear();

    // Enable mouse tracking (SGR mode for better coordinate support)
    terminal.write('\x1B[?1000h'); // Basic mouse tracking
    terminal.write('\x1B[?1002h'); // Button event tracking
    terminal.write('\x1B[?1003h'); // All motion tracking
    terminal.write('\x1B[?1006h'); // SGR mouse mode

    // Enable bracketed paste mode
    terminal.write('\x1B[?2004h');
    terminal.flush();

    // Wire up xterm.js input to nocterm
    xterminal.onOutput = (data) {
      final bytes = utf8.encode(data);
      _inputParser.addBytes(bytes);

      // Process all available events
      InputEvent? inputEvent;
      while ((inputEvent = _inputParser.parseNext()) != null) {
        if (inputEvent is KeyboardInputEvent) {
          final event = inputEvent.event;
          _keyboardEventController.add(event);
          _routeKeyboardEvent(event);
        } else if (inputEvent is MouseInputEvent) {
          final event = inputEvent.event;
          _mouseEventController.add(event);
          _routeMouseEvent(event);
        } else if (inputEvent is PasteInputEvent) {
          ClipboardManager.copy(inputEvent.text);
          final pasteEvent = KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: const ModifierKeys(ctrl: true),
          );
          _keyboardEventController.add(pasteEvent);
          _routeKeyboardEvent(pasteEvent);
        }
      }

      if (buildOwner.hasDirtyElements) {
        scheduleFrame();
      }
    };

    // Wire up xterm.js resize to nocterm
    xterminal.onResize = (width, height, pixelWidth, pixelHeight) {
      final newSize = Size(width.toDouble(), height.toDouble());
      terminal.updateSize(newSize);
      scheduleFrame();
    };
  }

  bool _routeKeyboardEvent(KeyboardEvent event) {
    if (rootElement == null) return false;
    return _dispatchKeyToElement(rootElement!, event);
  }

  void _routeMouseEvent(MouseEvent event) {
    if (rootElement == null) return;
    // Mouse handling can be added here if needed
  }

  bool _dispatchKeyToElement(Element element, KeyboardEvent event) {
    // First, try to dispatch to children (depth-first)
    bool handled = false;
    element.visitChildren((child) {
      if (!handled) {
        handled = _dispatchKeyToElement(child, event);
      }
    });

    // If no child handled it, and this element can handle keys, try it
    if (!handled && element is FocusableElement) {
      handled = element.handleKeyEvent(event);
    }

    return handled;
  }

  void shutdown() {
    try {
      _keyboardEventController.close();
      _mouseEventController.close();

      // Disable mouse tracking and bracketed paste
      xterminal.write('\x1B[?1003l');
      xterminal.write('\x1B[?1006l');
      xterminal.write('\x1B[?1002l');
      xterminal.write('\x1B[?1000l');
      xterminal.write('\x1B[?2004l');

      terminal.showCursor();
      terminal.leaveAlternateScreen();
      terminal.clear();
      terminal.flush();
    } catch (e) {
      // Ignore errors during cleanup
    }
  }

  @override
  void scheduleFrameImpl() {
    Timer.run(() {
      final now = DateTime.now();
      final timeStamp = Duration(microseconds: now.microsecondsSinceEpoch);
      handleBeginFrame(timeStamp);
    });
  }

  @override
  void handleDrawFrame() {
    if (rootElement == null) {
      super.handleDrawFrame();
      return;
    }
    super.handleDrawFrame();
  }

  void _drawFrameCallback(Duration timeStamp) {
    if (rootElement == null) return;

    super.drawFrame();

    final size = terminal.size;
    final buffer = buf.Buffer(size.width.toInt(), size.height.toInt());

    RenderObject? findRenderObject(Element element) {
      if (element is RenderObjectElement) {
        return element.renderObject;
      }
      RenderObject? result;
      element.visitChildren((child) {
        result ??= findRenderObject(child);
      });
      return result;
    }

    final renderObject = findRenderObject(rootElement!);
    if (renderObject != null) {
      if (renderObject.owner != pipelineOwner) {
        renderObject.attach(pipelineOwner);
      }

      renderObject.layout(BoxConstraints.tight(Size(size.width, size.height)));
      pipelineOwner.flushLayout();
      pipelineOwner.flushPaint();

      final canvas = TerminalCanvas(
        buffer,
        Rect.fromLTWH(0, 0, size.width, size.height),
      );
      renderObject.paintWithContext(canvas, Offset.zero);
    }

    // Render to terminal
    for (int y = 0; y < buffer.height; y++) {
      // Position cursor at start of each row explicitly
      // (don't rely on newlines which may not include carriage return in xterm.dart)
      terminal.moveTo(0, y);
      for (int x = 0; x < buffer.width; x++) {
        final cell = buffer.getCell(x, y);

        // Skip zero-width space markers (used for wide character tracking)
        // Don't write anything - just skip to next cell
        if (cell.char == '\u200B') {
          continue;
        }

        if (cell.style.color != null ||
            cell.style.backgroundColor != null ||
            cell.style.fontWeight == FontWeight.bold ||
            cell.style.fontWeight == FontWeight.dim ||
            cell.style.fontStyle == FontStyle.italic ||
            cell.style.decoration?.hasUnderline == true ||
            cell.style.reverse) {
          terminal.write(cell.style.toAnsi());
          terminal.write(cell.char);
          terminal.write(TextStyle.reset);
        } else {
          terminal.write(cell.char);
        }
      }
    }
    terminal.flush();
  }

  @override
  void initializeBinding() {
    super.initializeBinding();
    addPersistentFrameCallback(_drawFrameCallback);
  }
}
