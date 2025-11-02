import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm/src/framework/terminal_canvas.dart';
import 'package:nocterm/src/navigation/render_theater.dart';
import 'package:nocterm/src/rectangle.dart';
import 'package:nocterm/src/rendering/scrollable_render_object.dart';

import '../backend/terminal.dart' as term;
import '../buffer.dart' as buf;
import '../keyboard/input_parser.dart';
import '../keyboard/input_event.dart';
import '../keyboard/mouse_event.dart';
import '../components/block_focus.dart';
import '../rendering/mouse_tracker.dart';
import '../rendering/mouse_hit_test.dart';
import '../utils/log_server.dart';
import '../utils/logger.dart';
import '../utils/nocterm_paths.dart';
import 'hot_reload_mixin.dart';

/// Terminal UI binding that handles terminal input/output and event loop
class TerminalBinding extends NoctermBinding with HotReloadBinding {
  TerminalBinding(this.terminal, {Stream<List<int>>? inputStream})
      : _customInputStream = inputStream {
    _instance = this;
    _initializePipelineOwner();
  }

  static TerminalBinding? _instance;
  static TerminalBinding get instance => _instance!;

  final term.Terminal terminal;
  final Stream<List<int>>? _customInputStream;
  PipelineOwner? _pipelineOwner;
  PipelineOwner get pipelineOwner => _pipelineOwner!;

  // Expose buildOwner from the base class
  BuildOwner get buildOwner => super.buildOwner;

  Timer? _frameTimer;
  bool _shouldExit = false;
  final _inputController = StreamController<String>.broadcast();
  final _keyboardEventController = StreamController<KeyboardEvent>.broadcast();
  final _inputParser = InputParser();
  final _mouseEventController = StreamController<MouseEvent>.broadcast();
  final _mouseTracker = MouseTracker();

  // Event-driven loop support
  final _eventLoopController = StreamController<void>.broadcast();
  Stream<void> get _eventLoopStream => _eventLoopController.stream;

  // Post-frame callbacks
  final List<VoidCallback> _postFrameCallbacks = [];
  StreamSubscription? _inputSubscription;
  StreamSubscription? _sigwinchSubscription;
  StreamSubscription? _sigintSubscription;
  StreamSubscription? _sigtermSubscription;
  Size? _lastKnownSize;

  void _initializePipelineOwner() {
    _pipelineOwner = PipelineOwner();
    _pipelineOwner!.onNeedsVisualUpdate = scheduleFrame;
  }

  /// Stream of keyboard input events (raw strings)
  Stream<String> get input => _inputController.stream;

  /// Stream of parsed keyboard events
  Stream<KeyboardEvent> get keyboardEvents => _keyboardEventController.stream;

  /// Stream of parsed mouse events
  Stream<MouseEvent> get mouseEvents => _mouseEventController.stream;

  /// Initialize the terminal and start the event loop
  void initialize() {
    // Setup terminal
    terminal.enterAlternateScreen();
    terminal.hideCursor();
    terminal.clear();

    // Enable mouse tracking (SGR mode for better coordinate support)
    // ESC [ ? 1000 h - Send Mouse X & Y on button press and release
    // ESC [ ? 1002 h - Use Cell Motion Mouse Tracking
    // ESC [ ? 1003 h - Enable all motion mouse tracking
    // ESC [ ? 1006 h - Enable SGR mouse mode
    terminal.write('\x1B[?1000h'); // Basic mouse tracking
    terminal.write('\x1B[?1002h'); // Button event tracking
    terminal.write('\x1B[?1003h'); // All motion tracking
    terminal.write('\x1B[?1006h'); // SGR mouse mode

    // Enable bracketed paste mode
    // ESC [ ? 2004 h - Enables bracketed paste mode
    // When enabled, pasted text is wrapped in ESC[200~ ... ESC[201~
    // This allows applications to distinguish pasted text from typed text
    terminal.write('\x1B[?2004h'); // Bracketed paste mode
    terminal.flush();

    // Store initial size
    _lastKnownSize = terminal.size;

    // Start listening for keyboard input
    _startInputHandling();

    // Start listening for terminal resize events
    _startResizeHandling();

    // Start listening for termination signals
    _startSignalHandling();
  }

  void _startInputHandling() {
    // Use custom input stream if provided (for shell mode), otherwise use stdin
    final inputStream = _customInputStream ?? stdin;

    // Only set stdin mode if we're using stdin and have a terminal
    if (_customInputStream == null) {
      try {
        if (stdin.hasTerminal) {
          stdin.echoMode = false;
          stdin.lineMode = false;
        }
      } catch (e) {
        // Ignore errors when running without a proper terminal
        // This happens in CI/CD environments or when piping output
      }
    }

    // Listen for input at the byte level for proper escape sequence handling
    _inputSubscription = inputStream.listen((bytes) {
      // In shell mode, check for terminal size OSC sequences
      if (_customInputStream != null) {
        bytes = _processShellModeBytes(bytes);
      }

      // Parse the bytes and process ALL events in the buffer
      _inputParser.addBytes(bytes);

      // Process all available events
      InputEvent? inputEvent;
      while ((inputEvent = _inputParser.parseNext()) != null) {
        if (inputEvent is KeyboardInputEvent) {
          final event = inputEvent.event;
          // Add to keyboard event stream
          _keyboardEventController.add(event);

          // Route the event through the component tree
          _routeKeyboardEvent(event);

          // Note: Ctrl+C (SIGINT) is routed through the event system first,
          // allowing components to intercept it. Falls back to shutdown if unhandled.
        } else if (inputEvent is MouseInputEvent) {
          final event = inputEvent.event;

          // Add to mouse event stream
          _mouseEventController.add(event);

          // Route the mouse event through the component tree
          _routeMouseEvent(event);
        } else if (inputEvent is PasteInputEvent) {
          // Handle bracketed paste: copy to clipboard then send Ctrl+V
          ClipboardManager.copy(inputEvent.text);

          // Generate a Ctrl+V keyboard event to trigger the paste
          final pasteEvent = KeyboardEvent(
            logicalKey: LogicalKey.keyV,
            modifiers: const ModifierKeys(ctrl: true),
          );
          _keyboardEventController.add(pasteEvent);
          _routeKeyboardEvent(pasteEvent);
        }
      }

      // After processing ALL events in the buffer, draw the frame once
      // This ensures that pasted text (multiple characters) gets processed
      // completely before rendering, rather than blocking after each character
      if (buildOwner.hasDirtyElements) {
        drawFrame();
      }

      // Also add raw string for backwards compatibility
      try {
        final str = utf8.decode(bytes);
        _inputController.add(str);
      } catch (e) {
        // Ignore decode errors for escape sequences
      }
    });
  }

  /// Process bytes in shell mode to extract terminal size OSC sequences
  /// Returns filtered bytes with OSC sequences removed
  List<int> _processShellModeBytes(List<int> bytes) {
    final result = <int>[];
    int i = 0;

    while (i < bytes.length) {
      // Check for OSC 9999 sequence: ESC ] 9999 ; <cols> ; <rows> BEL
      if (i + 6 < bytes.length &&
          bytes[i] == 0x1b &&
          bytes[i + 1] == 0x5d) {
        // Found ESC ]
        // Look for the BEL terminator
        int end = i + 2;
        while (end < bytes.length && bytes[end] != 0x07) {
          end++;
        }

        if (end < bytes.length) {
          // Found complete OSC sequence
          final oscContent = utf8.decode(bytes.sublist(i + 2, end));

          // Check if it's our terminal size sequence
          if (oscContent.startsWith('9999;')) {
            final parts = oscContent.substring(5).split(';');
            if (parts.length == 2) {
              try {
                final cols = int.parse(parts[0]);
                final rows = int.parse(parts[1]);
                final newSize = Size(cols.toDouble(), rows.toDouble());

                // Update terminal size
                terminal.updateSize(newSize);
                _lastKnownSize = newSize;

                // Trigger a redraw with new size
                scheduleFrame();
              } catch (e) {
                // Invalid size, ignore
              }
            }
          }

          // Skip this OSC sequence
          i = end + 1;
          continue;
        }
      }

      // Regular byte, keep it
      result.add(bytes[i]);
      i++;
    }

    return result;
  }

  void _startResizeHandling() {
    // Listen for SIGWINCH signal on Unix systems
    if (Platform.isLinux || Platform.isMacOS) {
      _sigwinchSubscription = ProcessSignal.sigwinch.watch().listen((_) {
        _handleTerminalResize();
      });
    }

    // Also poll for size changes as a fallback
    // This helps on systems where SIGWINCH might not work properly
    Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_shouldExit) {
        _checkForSizeChange();
      }
    });
  }

  void _startSignalHandling() {
    // Listen for termination signals to ensure cleanup runs
    if (Platform.isLinux || Platform.isMacOS) {
      // Handle SIGINT (Ctrl+C)
      _sigintSubscription = ProcessSignal.sigint.watch().listen((_) {
        // Create a synthetic Ctrl+C keyboard event
        final ctrlCEvent = KeyboardEvent(
          logicalKey: LogicalKey.keyC,
          character: null,
          modifiers: const ModifierKeys(ctrl: true),
        );

        // Add to keyboard event stream for monitoring
        _keyboardEventController.add(ctrlCEvent);

        // Route through component tree - components can intercept by returning true
        final handled = _routeKeyboardEvent(ctrlCEvent);

        // If no component handled it, perform default shutdown
        if (!handled) {
          _performImmediateShutdown();
          exit(0);
        }
      });

      // Handle SIGTERM (kill command)
      _sigtermSubscription = ProcessSignal.sigterm.watch().listen((_) {
        // Perform cleanup synchronously
        _performImmediateShutdown();

        // Exit immediately
        exit(0);
      });
    }
  }

  /// Perform immediate synchronous shutdown for signal handlers
  void _performImmediateShutdown() {
    // Prevent multiple shutdowns
    if (_shouldExit) return;
    _shouldExit = true;

    // Cancel all timers and subscriptions immediately
    _frameTimer?.cancel();
    _inputSubscription?.cancel();
    _sigwinchSubscription?.cancel();
    _sigintSubscription?.cancel();
    _sigtermSubscription?.cancel();

    // Close all controllers
    try {
      _inputController.close();
    } catch (_) {}
    try {
      _keyboardEventController.close();
    } catch (_) {}
    try {
      _mouseEventController.close();
    } catch (_) {}
    try {
      _eventLoopController.close();
    } catch (_) {}

    // Stop hot reload if it was initialized
    try {
      shutdownWithHotReload();
    } catch (_) {}

    // Perform terminal cleanup synchronously
    try {
      // IMPORTANT: Disable mouse tracking BEFORE leaving alternate screen
      terminal.write('\x1B[?1003l'); // Disable all motion tracking
      terminal.write('\x1B[?1006l'); // Disable SGR mouse mode
      terminal.write('\x1B[?1002l'); // Disable button event tracking
      terminal.write('\x1B[?1000l'); // Disable basic mouse tracking
      terminal.flush();

      // Restore terminal
      terminal.showCursor();
      terminal.leaveAlternateScreen();
      terminal.clear();

      // Restore stdin (only in normal mode, not shell mode)
      if (_customInputStream == null && stdin.hasTerminal) {
        stdin.echoMode = true;
        stdin.lineMode = true;
      }
    } catch (_) {
      // Ignore any errors during cleanup
    }
  }

  void _handleTerminalResize() {
    // Update terminal size and trigger a redraw
    if (stdout.hasTerminal) {
      final newSize = Size(stdout.terminalColumns.toDouble(), stdout.terminalLines.toDouble());
      if (_lastKnownSize == null ||
          _lastKnownSize!.width != newSize.width ||
          _lastKnownSize!.height != newSize.height) {
        _lastKnownSize = newSize;
        // Update the terminal's cached size
        terminal.updateSize(newSize);
        // Schedule a frame redraw
        scheduleFrame();
      }
    }
  }

  void _checkForSizeChange() {
    // Periodic check for size changes (fallback for systems without SIGWINCH)
    if (stdout.hasTerminal) {
      final currentSize = Size(stdout.terminalColumns.toDouble(), stdout.terminalLines.toDouble());
      if (_lastKnownSize == null ||
          _lastKnownSize!.width != currentSize.width ||
          _lastKnownSize!.height != currentSize.height) {
        _handleTerminalResize();
      }
    }
  }

  /// Route a keyboard event through the component tree
  /// Returns true if the event was handled by a component
  bool _routeKeyboardEvent(KeyboardEvent event) {
    if (rootElement == null) return false;

    // Try to dispatch the event to the root element
    // The event will bubble through focused components
    return _dispatchKeyToElement(rootElement!, event);
  }

  /// Route a mouse event through the component tree
  void _routeMouseEvent(MouseEvent event) {
    if (rootElement == null) {
      return;
    }

    // Handle wheel events for scrollable widgets
    if (event.button == MouseButton.wheelUp || event.button == MouseButton.wheelDown) {
      // Find the render object at the mouse position
      final renderObject = _findRenderObjectInTree(rootElement!);
      if (renderObject != null) {
        _dispatchMouseWheelAtPosition(rootElement!, event, Offset(event.x.toDouble(), event.y.toDouble()), Offset.zero);
      }
    }

    // Perform hit test for all mouse events
    final renderObject = _findRenderObjectInTree(rootElement!);
    if (renderObject != null) {
      final hitTestResult = MouseHitTestResult();
      // Mouse coordinates are already 0-based (converted by MouseParser)
      final position = Offset(event.x.toDouble(), event.y.toDouble());

      // Perform hit test from the root render object
      renderObject.hitTest(hitTestResult, position: position);

      // Update mouse tracker with hit test results
      _mouseTracker.updateAnnotations(hitTestResult, event);
    }
  }

  /// Find the render object in the element tree
  RenderObject? _findRenderObjectInTree(Element element) {
    if (element is RenderObjectElement) {
      return element.renderObject;
    }
    RenderObject? result;
    element.visitChildren((child) {
      result ??= _findRenderObjectInTree(child);
    });
    return result;
  }

  /// Dispatch a keyboard event to an element and its children
  bool _dispatchKeyToElement(Element element, KeyboardEvent event) {
    // Check if this element is a BlockFocus that's blocking
    if (element is BlockFocusElement && element.isBlocking) {
      // Block all keyboard events from reaching children
      return false; // Event is "handled" (blocked)
    }

    // TODO: This is a hack to handle RenderTheater specially for Navigator
    // Should be properly integrated into the render object hierarchy
    if (element.renderObject is RenderTheater) {
      final multiChildRenderObject = element as MultiChildRenderObjectElement;
      if (multiChildRenderObject.children.length > 0) {
        final child = multiChildRenderObject.children.last;
        return _dispatchKeyToElement(child, event);
      }
    }

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

  /// Dispatch a mouse wheel event to scrollable RenderObjects at a specific position
  bool _dispatchMouseWheelAtPosition(Element element, MouseEvent event, Offset mousePos, Offset currentOffset) {
    // TODO: This is a hack to handle RenderTheater specially for Navigator
    // Should be properly integrated into the render object hierarchy
    if (element.renderObject is RenderTheater) {
      final multiChildRenderObject = element as MultiChildRenderObjectElement;
      if (multiChildRenderObject.children.length > 0) {
        final child = multiChildRenderObject.children.last;
        return _dispatchMouseWheelAtPosition(child, event, mousePos, currentOffset);
      }
    }

    // Calculate this element's bounds if it has a render object
    Rect? elementBounds;
    RenderObject? renderObject;

    if (element is RenderObjectElement) {
      renderObject = element.renderObject;
      final size = renderObject.size;

      // Get the offset from parent data if available
      Offset localOffset = currentOffset;
      if (renderObject.parentData is BoxParentData) {
        final boxParentData = renderObject.parentData as BoxParentData;
        localOffset = currentOffset + boxParentData.offset;
      }

      elementBounds = Rect.fromLTWH(
        localOffset.dx,
        localOffset.dy,
        size.width,
        size.height,
      );
    }

    // Check if mouse is within this element's bounds
    bool isWithinBounds = elementBounds?.contains(mousePos) ?? true;

    if (!isWithinBounds) {
      return false; // Mouse is outside this element
    }

    // Try to dispatch to children first (depth-first, but only if within their bounds)
    bool handled = false;

    // Calculate offset for children
    Offset childrenOffset = currentOffset;
    if (element is RenderObjectElement && elementBounds != null) {
      // Use the element's actual position for its children
      childrenOffset = Offset(elementBounds.left, elementBounds.top);
    }

    element.visitChildren((child) {
      if (!handled) {
        handled = _dispatchMouseWheelAtPosition(child, event, mousePos, childrenOffset);
      }
    });

    // If no child handled it and this element's render object is scrollable, handle it here
    if (!handled && renderObject != null && renderObject is ScrollableRenderObjectMixin) {
      final scrollableRenderObject = renderObject as ScrollableRenderObjectMixin;
      // Check if the render object implements scrolling through duck typing
      // This allows the RenderObject to handle scrolling without importing the mixin
      handled = scrollableRenderObject.handleMouseWheel(event);
    }

    return handled;
  }

  /// Run the main event loop
  Future<void> runEventLoop() async {
    // Initial frame
    drawFrame();

    // Keep the app running until shutdown is called
    // Use a completer-based approach for truly event-driven behavior
    final exitCompleter = Completer<void>();

    // Listen to the event stream
    final subscription = _eventLoopStream.listen((_) {
      // Events are handled by scheduleFrame, nothing to do here
    });

    // Check periodically for exit condition (much less frequently)
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_shouldExit) {
        timer.cancel();
        subscription.cancel();
        if (!exitCompleter.isCompleted) {
          exitCompleter.complete();
        }
      }
    });

    // Wait until we should exit
    await exitCompleter.future;
  }

  /// Shutdown the terminal and cleanup
  void shutdown() {
    // Prevent multiple shutdowns
    if (_shouldExit) return;

    _shouldExit = true;
    _frameTimer?.cancel();
    _inputSubscription?.cancel();
    _sigwinchSubscription?.cancel();

    // Don't cancel signal subscriptions here - let them stay active
    // so they can handle additional signals if needed
    // _sigintSubscription?.cancel();
    // _sigtermSubscription?.cancel();

    try {
      _inputController.close();
    } catch (_) {}
    try {
      _keyboardEventController.close();
    } catch (_) {}
    try {
      _mouseEventController.close();
    } catch (_) {}

    // Wake up event loop one last time before closing
    if (!_eventLoopController.isClosed) {
      _eventLoopController.add(null);
      _eventLoopController.close();
    }

    // Stop hot reload if it was initialized
    shutdownWithHotReload();

    // Try to cleanup terminal, but handle errors gracefully
    try {
      // IMPORTANT: Disable mouse tracking and bracketed paste BEFORE leaving alternate screen
      // This ensures the terminal properly processes the disable commands
      stdout.write('\x1B[?1003l'); // Disable all motion tracking FIRST
      stdout.write('\x1B[?1006l'); // Disable SGR mouse mode
      stdout.write('\x1B[?1002l'); // Disable button event tracking
      stdout.write('\x1B[?1000l'); // Disable basic mouse tracking LAST
      stdout.write('\x1B[?2004l'); // Disable bracketed paste mode

      // Flush to ensure disable commands are sent immediately
      stdout.flush();

      // Restore terminal (this includes leaving alternate screen)
      terminal.showCursor();
      terminal.leaveAlternateScreen();

      // CRITICAL: Disable mouse tracking again after leaving alternate screen
      // Some terminals restore previous state when switching buffers
      stdout.write('\x1B[?1003l'); // Disable all motion tracking
      stdout.write('\x1B[?1006l'); // Disable SGR mouse mode
      stdout.write('\x1B[?1002l'); // Disable button event tracking
      stdout.write('\x1B[?1000l'); // Disable basic mouse tracking

      // Send a terminal reset sequence as a final safety measure
      // This helps ensure the terminal is in a clean state
      stdout.write('\x1B[c'); // Reset Device Attributes (soft reset)

      stdout.flush();

      terminal.clear();

      // Final flush to ensure all cleanup is complete
      terminal.flush();
    } catch (e) {
      // If stdout is already closed or bound, we can't write to it
      // This can happen during signal-based shutdown
      // The important thing is we tried to cleanup
    }

    // Restore stdin if we have a terminal
    try {
      if (stdin.hasTerminal) {
        stdin.echoMode = true;
        stdin.lineMode = true;
      }
    } catch (e) {
      // Ignore errors when running without a proper terminal
    }
  }

  @override
  void scheduleFrame() {
    // Cancel any existing timer
    _frameTimer?.cancel();

    // Schedule frame to be drawn on next microtask
    // This batches updates that happen in the same event loop iteration
    _frameTimer = Timer(Duration.zero, () {
      drawFrame();
      _frameTimer = null;
    });

    // Wake up the event loop
    if (!_eventLoopController.isClosed) {
      _eventLoopController.add(null);
    }
  }

  @override
  void drawFrame() {
    if (rootElement == null) return;

    // Build phase
    super.drawFrame();

    // Get current terminal size (may have been updated by resize event)
    final size = terminal.size;
    final buffer = buf.Buffer(size.width.toInt(), size.height.toInt());

    // Find render object in tree
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
      // Attach render object to pipeline owner if needed
      if (renderObject.owner != pipelineOwner) {
        renderObject.attach(pipelineOwner);
      }

      // Layout phase
      renderObject.layout(BoxConstraints.tight(Size(size.width.toDouble(), size.height.toDouble())));

      // Flush layout pipeline
      pipelineOwner.flushLayout();

      // Flush paint pipeline
      pipelineOwner.flushPaint();

      // Paint phase - actually render to canvas
      final canvas = TerminalCanvas(
        buffer,
        Rect.fromLTWH(0, 0, size.width.toDouble(), size.height.toDouble()),
      );
      renderObject.paintWithContext(canvas, Offset.zero);
    }

    // Render to terminal
    terminal.moveTo(0, 0);
    for (int y = 0; y < buffer.height; y++) {
      for (int x = 0; x < buffer.width; x++) {
        final cell = buffer.getCell(x, y);

        // Skip zero-width space markers (used for emoji second column)
        if (cell.char == '\u200B') {
          continue;
        }

        // Apply style if present
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
      if (y < buffer.height - 1) {
        terminal.write('\n');
      }
    }
    terminal.flush();

    // Execute post-frame callbacks
    final callbacks = List<VoidCallback>.from(_postFrameCallbacks);
    _postFrameCallbacks.clear();
    for (final callback in callbacks) {
      callback();
    }
  }

  /// Schedules a callback to be executed after the next frame is drawn.
  ///
  /// This is useful for performing actions that depend on the layout being
  /// complete, such as scrolling to a specific position after adding content.
  void addPostFrameCallback(VoidCallback callback) {
    _postFrameCallbacks.add(callback);
    // Schedule a frame if one isn't already scheduled
    scheduleFrame();
  }

  /// Request application shutdown with proper cleanup
  ///
  /// This is the recommended way to exit a nocterm application.
  /// It ensures all terminal cleanup (including mouse tracking disable)
  /// happens before the process exits.
  ///
  /// IMPORTANT: Do NOT call dart:io's exit() directly, as it will bypass
  /// terminal cleanup and may leave the terminal in a broken state (e.g.,
  /// mouse movement producing escape sequences).
  ///
  /// Instead, always use this method or set [_shouldExit] to true.
  void requestShutdown([int exitCode = 0]) {
    _performImmediateShutdown();
    exit(exitCode);
  }
}

/// Run a TUI application
///
/// Automatically detects if a nocterm shell is running by checking for
/// the shell_handle file in the global nocterm directory. If found, the app
/// will render into the shell instead of directly to stdout, allowing IDE
/// debugger support.
///
/// Logs are streamed via WebSocket and can be viewed with `nocterm logs`.
/// In shell mode, print() statements also appear in the host's stdout.
/// In normal mode, only WebSocket logs are available.
Future<void> runApp(Component app, {bool enableHotReload = true}) async {
  // Check for shell mode
  final shellHandleFile = File(getShellHandlePath());
  final useShellMode = await shellHandleFile.exists();

  if (useShellMode) {
    // Shell mode: connect to nocterm shell
    // In this mode, prints go to both WebSocket logs and host stdout
    await _runAppInShellMode(app, shellHandleFile, enableHotReload);
  } else {
    // Normal mode: render directly to terminal
    // In this mode, prints go to WebSocket logs since stdout is used for TUI
    await _runAppNormalMode(app, enableHotReload);
  }
}

/// Run app in normal mode (direct terminal rendering)
Future<void> _runAppNormalMode(Component app, bool enableHotReload) async {
  TerminalBinding? binding;
  LogServer? logServer;
  Logger? logger;

  try {
    // Start log server
    logServer = LogServer();
    try {
      await logServer.start();
      logger = Logger(logServer: logServer);
    } catch (e) {
      stderr.writeln('Failed to start log server: $e');
      // Continue without logging
    }

    await runZoned(() async {
      final terminal = term.Terminal();
      binding = TerminalBinding(terminal);

      binding!.initialize();
      binding!.attachRootComponent(app);

      // Initialize hot reload in development mode
      if (enableHotReload && !bool.fromEnvironment('dart.vm.product')) {
        await binding!.initializeHotReload();
      }

      await binding!.runEventLoop();
    },
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String message) {
            // Write to logger via WebSocket
            logger?.log(message);
          },
          handleUncaughtError: (Zone self, ZoneDelegate parent, Zone zone, Object error, StackTrace stackTrace) {
            // Log errors with stack traces
            logger?.log('ERROR: $error\n$stackTrace');
          },
        ));
  } catch (e) {
    // If we exit via signal handler, this might throw
    // Just ensure cleanup happens
  } finally {
    // Ensure binding cleanup if not already done
    if (binding != null && !binding!._shouldExit) {
      binding!.shutdown();
    }

    // Close logger and log server gracefully
    try {
      await logger?.close();
      await logServer?.close();
    } catch (_) {
      // Ignore errors if already closed
    }
  }
}

/// Run app in shell mode (render to nocterm shell via socket)
Future<void> _runAppInShellMode(Component app, File shellHandleFile, bool enableHotReload) async {
  TerminalBinding? binding;
  LogServer? logServer;
  Logger? logger;

  try {
    // Start log server
    logServer = LogServer();
    try {
      await logServer.start();
      logger = Logger(logServer: logServer);
    } catch (e) {
      stderr.writeln('Failed to start log server: $e');
      // Continue without logging
    }

    // Read socket path from handle file
    final socketPath = await shellHandleFile.readAsString();

    // Connect to shell socket
    final socket = await Socket.connect(
      InternetAddress(socketPath.trim(), type: InternetAddressType.unix),
      0,
    );

    await runZoned(() async {
      // Use SocketTerminal which writes to socket instead of stdout
      // And use socket as input stream instead of stdin
      final terminal = term.SocketTerminal(socket);
      binding = TerminalBinding(terminal, inputStream: socket);

      binding!.initialize();
      binding!.attachRootComponent(app);

      // Initialize hot reload in development mode
      if (enableHotReload && !bool.fromEnvironment('dart.vm.product')) {
        await binding!.initializeHotReload();
      }

      await binding!.runEventLoop();
    },
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String message) {
            // In shell mode, print() goes to both:
            // 1. WebSocket logs (for nocterm logs command)
            logger?.log(message);
            // 2. Host's stdout (IDE/terminal for immediate debugging)
            parent.print(zone, message);
          },
          handleUncaughtError: (Zone self, ZoneDelegate parent, Zone zone, Object error, StackTrace stackTrace) {
            // Errors also go to both
            final errorMessage = 'ERROR: $error\n$stackTrace';
            logger?.log(errorMessage);
            stderr.writeln(errorMessage);
          },
        ));
  } catch (e) {
    // Log connection errors to stderr in shell mode
    stderr.writeln('Shell mode error: $e');
  } finally {
    // Ensure binding cleanup if not already done
    if (binding != null && !binding!._shouldExit) {
      binding!.shutdown();
    }

    // Close logger and log server gracefully
    try {
      await logger?.close();
      await logServer?.close();
    } catch (_) {
      // Ignore errors if already closed
    }
  }
}
