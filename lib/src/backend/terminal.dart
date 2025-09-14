import 'dart:io';
import 'package:nocterm/src/size.dart';

class Position {
  final int x;
  final int y;

  const Position(this.x, this.y);
}

class Terminal {
  late Size _size;
  bool _altScreenEnabled = false;

  // Write buffer for batching output
  final StringBuffer _writeBuffer = StringBuffer();

  // ANSI escape codes for terminal control
  static const _hideCursor = '\x1b[?25l';
  static const _showCursor = '\x1b[?25h';
  static const _clearScreen = '\x1b[2J';
  static const _clearLine = '\x1b[2K';
  static const _moveCursorHome = '\x1b[H';
  static const _alternateBuffer = '\x1b[?1049h';
  static const _mainBuffer = '\x1b[?1049l';

  Terminal({Size? size}) {
    _size = size ?? _getTerminalSize();
  }

  Size get size => _size;

  void updateSize(Size newSize) {
    _size = newSize;
  }

  static Size _getTerminalSize() {
    if (stdout.hasTerminal) {
      return Size(stdout.terminalColumns.toDouble(), stdout.terminalLines.toDouble());
    }
    return const Size(80, 80);
  }

  void enterAlternateScreen() {
    if (!_altScreenEnabled) {
      // These need immediate effect, so flush any pending writes first
      flush();
      stdout.write(_alternateBuffer);
      clear();
      _altScreenEnabled = true;
    }
  }

  void leaveAlternateScreen() {
    if (_altScreenEnabled) {
      // These need immediate effect, so flush any pending writes first
      flush();
      stdout.write(_mainBuffer);
      _altScreenEnabled = false;
    }
  }

  void hideCursor() {
    // Buffer this - will be flushed with frame
    write(_hideCursor);
  }

  void showCursor() {
    // This needs immediate effect when exiting
    flush();
    stdout.write(_showCursor);
  }

  void clear() {
    // Buffer this - will be flushed with frame
    write(_clearScreen);
    write(_moveCursorHome);
  }

  void clearLine() {
    // Buffer this - will be flushed with frame
    write(_clearLine);
  }

  void moveCursor(int x, int y) {
    write('\x1b[${y + 1};${x + 1}H');
  }

  void moveToHome() {
    write(_moveCursorHome);
  }

  void moveTo(int x, int y) {
    moveCursor(x, y);
  }

  void write(String text) {
    _writeBuffer.write(text);
  }

  void flush() {
    if (_writeBuffer.isNotEmpty) {
      stdout.write(_writeBuffer.toString());
      _writeBuffer.clear();
    }
    stdout.flush();
  }

  void reset() {
    showCursor();
    leaveAlternateScreen();
    stdout.write('\x1b[0m'); // Reset all attributes
  }
}
