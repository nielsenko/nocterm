library tui.terminal_canvas;

import 'dart:math' as math;
import 'package:nocterm/src/rectangle.dart';

import '../buffer.dart';
import '../style.dart';
import '../utils/unicode_width.dart';
import 'framework.dart';

/// Canvas for drawing to the terminal
class TerminalCanvas {
  TerminalCanvas(this.buffer, this.area);

  final Buffer buffer;
  final Rect area;

  /// Draw text at the given position
  void drawText(Offset position, String text, {TextStyle? style}) {
    final x = position.dx.round();
    final y = position.dy.round();

    if (x < 0 || y < 0 || x >= area.width || y >= area.height) {
      return;
    }

    final runes = text.runes.toList();
    int currentColumn = x;

    for (int i = 0; i < runes.length && currentColumn < area.width; i++) {
      final rune = runes[i];
      final char = String.fromCharCode(rune);
      final width = UnicodeWidth.runeWidth(rune);

      // Skip zero-width characters
      if (width == 0) {
        continue;
      }

      // Check if we have enough space for wide characters
      if (width == 2 && currentColumn + 1 >= area.width) {
        break;
      }

      // Set the main cell
      final cellX = area.left.round() + currentColumn;
      final cellY = area.top.round() + y;

      // Get existing cell to preserve background if needed
      final existingCell = buffer.getCell(cellX, cellY);
      final effectiveStyle = style ?? const TextStyle();

      // If no background is set in the style, preserve the existing background
      final finalStyle = effectiveStyle.backgroundColor == null
          ? effectiveStyle.copyWith(backgroundColor: existingCell.style.backgroundColor)
          : effectiveStyle;

      buffer.setCell(
        cellX,
        cellY,
        Cell(
          char: char,
          style: finalStyle,
        ),
      );

      // For wide characters, we need to mark the next cell as occupied
      // but without rendering anything there (the terminal handles the width)
      if (width == 2 && currentColumn + 1 < area.width) {
        // Mark the cell as occupied by the emoji's second half
        // We use a special marker that won't be rendered
        final nextCellX = area.left.round() + currentColumn + 1;
        final nextCellY = area.top.round() + y;

        // Get existing cell to preserve background if needed
        final nextExistingCell = buffer.getCell(nextCellX, nextCellY);
        final nextEffectiveStyle = style ?? const TextStyle();

        // If no background is set in the style, preserve the existing background
        final nextFinalStyle = nextEffectiveStyle.backgroundColor == null
            ? nextEffectiveStyle.copyWith(backgroundColor: nextExistingCell.style.backgroundColor)
            : nextEffectiveStyle;

        buffer.setCell(
          nextCellX,
          nextCellY,
          Cell(
            char: '\u200B', // Zero-width space as a marker
            style: nextFinalStyle,
          ),
        );
      }

      currentColumn += width;
    }
  }

  /// Fill a rectangle with a character
  void fillRect(Rect rect, String char, {TextStyle? style}) {
    final left = math.max(0, rect.left.round());
    final top = math.max(0, rect.top.round());
    final right = math.min(area.width, (rect.left + rect.width).round());
    final bottom = math.min(area.height, (rect.top + rect.height).round());

    for (int y = top; y < bottom; y++) {
      for (int x = left; x < right; x++) {
        buffer.setCell(
          area.left.round() + x,
          area.top.round() + y,
          Cell(
            char: char,
            style: style ?? const TextStyle(),
          ),
        );
      }
    }
  }

  /// Draw a box with borders
  void drawBox(Rect rect, {BorderStyle? border, TextStyle? style}) {
    if (border == null) return;

    final left = rect.left.round();
    final top = rect.top.round();
    final right = (rect.left + rect.width - 1).round();
    final bottom = (rect.top + rect.height - 1).round();

    // Corners
    _drawChar(left, top, border.topLeft, style);
    _drawChar(right, top, border.topRight, style);
    _drawChar(left, bottom, border.bottomLeft, style);
    _drawChar(right, bottom, border.bottomRight, style);

    // Top and bottom borders
    for (int x = left + 1; x < right; x++) {
      _drawChar(x, top, border.horizontal, style);
      _drawChar(x, bottom, border.horizontal, style);
    }

    // Left and right borders
    for (int y = top + 1; y < bottom; y++) {
      _drawChar(left, y, border.vertical, style);
      _drawChar(right, y, border.vertical, style);
    }
  }

  /// Draw a single character
  void _drawChar(int x, int y, String char, TextStyle? style) {
    if (x < 0 || y < 0 || x >= area.width || y >= area.height) {
      return;
    }

    buffer.setCell(
      area.left.round() + x,
      area.top.round() + y,
      Cell(
        char: char,
        style: style ?? const TextStyle(),
      ),
    );
  }

  /// Create a clipped canvas for drawing within a sub-region
  TerminalCanvas clip(Rect clipRect) {
    final clippedArea = _intersect(
      Rect.fromLTWH(
        area.left + clipRect.left,
        area.top + clipRect.top,
        clipRect.width,
        clipRect.height,
      ),
      area,
    );
    return TerminalCanvas(buffer, clippedArea);
  }

  Rect _intersect(Rect a, Rect b) {
    final left = math.max(a.left, b.left);
    final top = math.max(a.top, b.top);
    final right = math.min(a.right, b.right);
    final bottom = math.min(a.bottom, b.bottom);

    if (left >= right || top >= bottom) {
      return const Rect.fromLTWH(0, 0, 0, 0);
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }
}

/// Border style for boxes
class BorderStyle {
  const BorderStyle({
    this.topLeft = '┌',
    this.topRight = '┐',
    this.bottomLeft = '└',
    this.bottomRight = '┘',
    this.horizontal = '─',
    this.vertical = '│',
  });

  final String topLeft;
  final String topRight;
  final String bottomLeft;
  final String bottomRight;
  final String horizontal;
  final String vertical;

  static const BorderStyle single = BorderStyle();

  static const BorderStyle double = BorderStyle(
    topLeft: '╔',
    topRight: '╗',
    bottomLeft: '╚',
    bottomRight: '╝',
    horizontal: '═',
    vertical: '║',
  );

  static const BorderStyle rounded = BorderStyle(
    topLeft: '╭',
    topRight: '╮',
    bottomLeft: '╰',
    bottomRight: '╯',
    horizontal: '─',
    vertical: '│',
  );

  static const BorderStyle thick = BorderStyle(
    topLeft: '┏',
    topRight: '┓',
    bottomLeft: '┗',
    bottomRight: '┛',
    horizontal: '━',
    vertical: '┃',
  );
}
