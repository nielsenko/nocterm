import 'package:nocterm/nocterm.dart';
import 'package:nocterm/src/framework/terminal_canvas.dart';

/// Title alignment options for border titles
enum TitleAlignment {
  left,
  center,
  right,
}

/// Configuration for a title embedded in a border
class BorderTitle {
  const BorderTitle({
    required this.text,
    this.alignment = TitleAlignment.left,
    this.style,
  });

  final String text;
  final TitleAlignment alignment;
  final TextStyle? style;
}

/// Border side configuration for a box decoration
class BorderSide {
  const BorderSide({
    this.color = const Color.fromRGB(255, 255, 255),
    this.width = 1.0,
    this.style = BoxBorderStyle.solid,
  });

  final Color color;
  final double width;
  final BoxBorderStyle style;

  static const BorderSide none = BorderSide(style: BoxBorderStyle.none);

  bool get isNone => style == BoxBorderStyle.none || width == 0.0;
}

/// Border style options
enum BoxBorderStyle {
  none,
  solid,
  dashed,
  dotted,
  double,
  rounded,
}

/// Box border configuration
class BoxBorder {
  const BoxBorder({
    this.top = BorderSide.none,
    this.right = BorderSide.none,
    this.bottom = BorderSide.none,
    this.left = BorderSide.none,
  });

  BoxBorder.all({
    Color color = const Color.fromRGB(255, 255, 255),
    double width = 1.0,
    BoxBorderStyle style = BoxBorderStyle.solid,
  })  : top = BorderSide(color: color, width: width, style: style),
        right = BorderSide(color: color, width: width, style: style),
        bottom = BorderSide(color: color, width: width, style: style),
        left = BorderSide(color: color, width: width, style: style);

  final BorderSide top;
  final BorderSide right;
  final BorderSide bottom;
  final BorderSide left;

  bool get hasNoBorder =>
      top.isNone && right.isNone && bottom.isNone && left.isNone;
}

/// Box shadow configuration
class BoxShadow {
  const BoxShadow({
    this.color = const Color.fromRGB(0, 0, 0),
    this.offset = Offset.zero,
    this.blurRadius = 0.0,
    this.spreadRadius = 0.0,
  });

  final Color color;
  final Offset offset;
  final double blurRadius;
  final double spreadRadius;
}

/// Border radius configuration
class BorderRadius {
  const BorderRadius.only({
    this.topLeft = Radius.zero,
    this.topRight = Radius.zero,
    this.bottomLeft = Radius.zero,
    this.bottomRight = Radius.zero,
  });

  const BorderRadius.all(Radius radius)
      : topLeft = radius,
        topRight = radius,
        bottomLeft = radius,
        bottomRight = radius;

  BorderRadius.circular(double radius)
      : topLeft = Radius.circular(radius),
        topRight = Radius.circular(radius),
        bottomLeft = Radius.circular(radius),
        bottomRight = Radius.circular(radius);

  final Radius topLeft;
  final Radius topRight;
  final Radius bottomLeft;
  final Radius bottomRight;

  static const BorderRadius zero = BorderRadius.all(Radius.zero);

  bool get isZero =>
      topLeft == Radius.zero &&
      topRight == Radius.zero &&
      bottomLeft == Radius.zero &&
      bottomRight == Radius.zero;
}

/// Radius configuration
class Radius {
  const Radius.circular(double radius)
      : x = radius,
        y = radius;
  const Radius.elliptical(this.x, this.y);

  final double x;
  final double y;

  static const Radius zero = Radius.circular(0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Radius && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Decoration for a box
class BoxDecoration {
  const BoxDecoration({
    this.color,
    this.image,
    this.border,
    this.borderRadius,
    this.boxShadow,
    this.gradient,
    this.backgroundBlendMode,
    this.shape = BoxShape.rectangle,
    this.title,
  });

  final Color? color;
  final DecorationImage? image;
  final BoxBorder? border;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;
  final BlendMode? backgroundBlendMode;
  final BoxShape shape;
  final BorderTitle? title;
}

/// Shape of the box
enum BoxShape {
  rectangle,
  circle,
}

/// Decoration image (placeholder for future implementation)
class DecorationImage {
  const DecorationImage({required this.image});
  final Object image;
}

/// Gradient (placeholder for future implementation)
abstract class Gradient {
  const Gradient();
}

/// Linear gradient
class LinearGradient extends Gradient {
  const LinearGradient({
    this.begin = Alignment.centerLeft,
    this.end = Alignment.centerRight,
    required this.colors,
    this.stops,
  });

  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final List<Color> colors;
  final List<double>? stops;
}

/// Blend mode (placeholder)
enum BlendMode {
  normal,
  multiply,
  screen,
  overlay,
}

/// RenderObject that applies decoration to its child
class RenderDecoratedBox extends RenderObject
    with RenderObjectWithChildMixin<RenderObject> {
  RenderDecoratedBox({
    required BoxDecoration decoration,
    DecorationPosition position = DecorationPosition.background,
  })  : _decoration = decoration,
        _position = position;

  BoxDecoration _decoration;
  BoxDecoration get decoration => _decoration;
  set decoration(BoxDecoration value) {
    if (_decoration != value) {
      _decoration = value;
      markNeedsLayout();
    }
  }

  DecorationPosition _position;
  DecorationPosition get position => _position;
  set position(DecorationPosition value) {
    if (_position != value) {
      _position = value;
      markNeedsPaint();
    }
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  @override
  void performLayout() {
    // Calculate border insets
    double borderInset = 0;
    if (_decoration.border != null && !_decoration.border!.hasNoBorder) {
      // In terminal, we can only draw 1-character wide borders
      // So we treat any border as taking up 1 unit of space
      borderInset = 1;
    }

    if (child != null) {
      // Deflate constraints by border width
      final childConstraints = constraints.deflate(EdgeInsets.all(borderInset));

      // Layout child with deflated constraints
      child!.layout(childConstraints, parentUsesSize: true);

      // Our size includes the border
      size = constraints.constrain(
        Size(
          child!.size.width + 2 * borderInset,
          child!.size.height + 2 * borderInset,
        ),
      );

      // Position child inside the border
      final BoxParentData childParentData = child!.parentData as BoxParentData;
      childParentData.offset = Offset(borderInset, borderInset);
    } else {
      // No child, just be the size of the border
      size = constraints.constrain(Size(2 * borderInset, 2 * borderInset));
    }
  }

  void _paintDecoration(TerminalCanvas canvas, Offset offset) {
    // Create rect in absolute canvas coordinates for background
    final absoluteRect =
        Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);

    // Paint background color
    if (_decoration.color != null) {
      _paintBackground(canvas, absoluteRect, _decoration.color!);
    }

    // Paint border - pass the offset for absolute positioning
    if (_decoration.border != null && !_decoration.border!.hasNoBorder) {
      _paintBorder(canvas, offset, _decoration.border!);
    }
  }

  void _paintBackground(TerminalCanvas canvas, Rect rect, Color color) {
    final style = TextStyle(backgroundColor: color);
    // Paint the background by filling the rect area
    canvas.fillRect(rect, ' ', style: style);
  }

  void _setCell(
      TerminalCanvas canvas, int x, int y, String char, TextStyle style) {
    // x and y are already in absolute canvas coordinates
    // Check bounds against the absolute buffer area
    final bufferX = canvas.area.left.round() + x;
    final bufferY = canvas.area.top.round() + y;

    // Check if we're within the canvas area bounds
    if (bufferX < canvas.area.left ||
        bufferY < canvas.area.top ||
        bufferX >= canvas.area.left + canvas.area.width ||
        bufferY >= canvas.area.top + canvas.area.height) {
      return;
    }

    canvas.buffer.setCell(
      bufferX,
      bufferY,
      Cell(
        char: char,
        style: style,
      ),
    );
  }

  void _paintBorder(TerminalCanvas canvas, Offset offset, BoxBorder border) {
    // Calculate border positions in absolute coordinates
    final left = offset.dx.round();
    final top = offset.dy.round();
    final right = (offset.dx + size.width).round() - 1;
    final bottom = (offset.dy + size.height).round() - 1;

    // Get border characters based on style
    final chars = _getBorderCharacters(border);

    // Paint top border
    if (!border.top.isNone) {
      final borderStyle = TextStyle(color: border.top.color);
      if (left == right) {
        // Special case: width is 1
        // Determine which character to use based on what borders exist
        String charToUse;
        if (!border.left.isNone && !border.right.isNone) {
          // Has left and right borders, use appropriate corner
          charToUse = chars
              .topLeft; // Since it's a 1-wide box, topLeft represents the entire top
        } else if (!border.left.isNone) {
          charToUse = chars.topLeft;
        } else if (!border.right.isNone) {
          charToUse = chars.topRight;
        } else {
          charToUse = chars.horizontal;
        }
        _setCell(canvas, left, top, charToUse, borderStyle);
      } else {
        // Use corner only if left border connects, otherwise use horizontal
        final leftTopChar =
            !border.left.isNone ? chars.topLeft : chars.horizontal;
        _setCell(canvas, left, top, leftTopChar, borderStyle);

        // Check if we have a title to render
        final title = _decoration.title;
        final horizontalWidth =
            right - left - 1; // Available width between corners

        if (title != null && horizontalWidth >= 5) {
          // Minimum width: space + 1 char title + space + some border chars
          // Format: ─ Title ─────
          final titleText = title.text;
          final titleStyle = title.style ?? borderStyle;

          // Calculate title display with " Title " format (space padding)
          // We need at least 2 horizontal chars for aesthetics
          final maxTitleWidth =
              horizontalWidth - 2; // Reserve 2 chars for border lines
          String displayTitle;
          if (titleText.length + 2 > maxTitleWidth) {
            // Truncate with ellipsis
            final truncateLen =
                maxTitleWidth - 3; // -3 for "..." and space padding
            if (truncateLen > 0) {
              displayTitle = ' ${titleText.substring(0, truncateLen)}… ';
            } else {
              // Not enough space even for ellipsis, skip title
              displayTitle = '';
            }
          } else {
            displayTitle = ' $titleText ';
          }

          if (displayTitle.isNotEmpty) {
            final titleWidth = displayTitle.length;
            final remainingWidth = horizontalWidth - titleWidth;

            int titleStartX;
            int leftBorderLen;
            int rightBorderLen;

            switch (title.alignment) {
              case TitleAlignment.left:
                leftBorderLen = 1; // Single horizontal char before title
                titleStartX = left + 1 + leftBorderLen;
                rightBorderLen = remainingWidth - leftBorderLen;
                break;
              case TitleAlignment.center:
                leftBorderLen = remainingWidth ~/ 2;
                titleStartX = left + 1 + leftBorderLen;
                rightBorderLen = remainingWidth - leftBorderLen;
                break;
              case TitleAlignment.right:
                rightBorderLen = 1; // Single horizontal char after title
                leftBorderLen = remainingWidth - rightBorderLen;
                titleStartX = left + 1 + leftBorderLen;
                break;
            }

            // Paint left horizontal chars
            for (int i = 0; i < leftBorderLen; i++) {
              _setCell(
                  canvas, left + 1 + i, top, chars.horizontal, borderStyle);
            }

            // Paint title
            for (int i = 0; i < displayTitle.length; i++) {
              _setCell(
                  canvas, titleStartX + i, top, displayTitle[i], titleStyle);
            }

            // Paint right horizontal chars
            final rightStartX = titleStartX + titleWidth;
            for (int i = 0; i < rightBorderLen; i++) {
              _setCell(
                  canvas, rightStartX + i, top, chars.horizontal, borderStyle);
            }
          } else {
            // Title too short, render normal border
            for (int x = left + 1; x < right; x++) {
              _setCell(canvas, x, top, chars.horizontal, borderStyle);
            }
          }
        } else {
          // No title or not enough space, render normal horizontal line
          for (int x = left + 1; x < right; x++) {
            _setCell(canvas, x, top, chars.horizontal, borderStyle);
          }
        }

        // Use corner only if right border connects, otherwise use horizontal
        final rightTopChar =
            !border.right.isNone ? chars.topRight : chars.horizontal;
        _setCell(canvas, right, top, rightTopChar, borderStyle);
      }
    }

    // Paint bottom border
    if (!border.bottom.isNone && bottom > top) {
      final style = TextStyle(color: border.bottom.color);
      if (left == right) {
        // Special case: width is 1
        // Determine which character to use based on what borders exist
        String charToUse;
        if (!border.left.isNone && !border.right.isNone) {
          // Has left and right borders, use appropriate corner
          charToUse = chars
              .bottomLeft; // Since it's a 1-wide box, bottomLeft represents the entire bottom
        } else if (!border.left.isNone) {
          charToUse = chars.bottomLeft;
        } else if (!border.right.isNone) {
          charToUse = chars.bottomRight;
        } else {
          charToUse = chars.horizontal;
        }
        _setCell(canvas, left, bottom, charToUse, style);
      } else {
        // Use corner only if left border connects, otherwise use horizontal
        final leftBottomChar =
            !border.left.isNone ? chars.bottomLeft : chars.horizontal;
        _setCell(canvas, left, bottom, leftBottomChar, style);
        for (int x = left + 1; x < right; x++) {
          _setCell(canvas, x, bottom, chars.horizontal, style);
        }
        // Use corner only if right border connects, otherwise use horizontal
        final rightBottomChar =
            !border.right.isNone ? chars.bottomRight : chars.horizontal;
        _setCell(canvas, right, bottom, rightBottomChar, style);
      }
    }

    // Paint left border
    if (!border.left.isNone) {
      final style = TextStyle(color: border.left.color);
      // Only paint vertical lines if there's space between top and bottom
      if (bottom > top) {
        for (int y = top + 1; y < bottom; y++) {
          _setCell(canvas, left, y, chars.vertical, style);
        }
      }
    }

    // Paint right border
    if (!border.right.isNone && right > left) {
      final style = TextStyle(color: border.right.color);
      // Only paint vertical lines if there's space between top and bottom
      if (bottom > top) {
        for (int y = top + 1; y < bottom; y++) {
          _setCell(canvas, right, y, chars.vertical, style);
        }
      }
    }
  }

  _BorderCharacters _getBorderCharacters(BoxBorder border) {
    // Determine the predominant border style
    BoxBorderStyle? style;
    for (final side in [border.top, border.right, border.bottom, border.left]) {
      if (!side.isNone) {
        style = side.style;
        break;
      }
    }

    switch (style) {
      case BoxBorderStyle.double:
        return _BorderCharacters.double;
      case BoxBorderStyle.rounded:
        return _BorderCharacters.rounded;
      case BoxBorderStyle.dashed:
        return _BorderCharacters.dashed;
      case BoxBorderStyle.dotted:
        return _BorderCharacters.dotted;
      case BoxBorderStyle.solid:
      case BoxBorderStyle.none:
      case null:
        return _BorderCharacters.single;
    }
  }

  @override
  void paint(TerminalCanvas canvas, Offset offset) {
    super.paint(canvas, offset);
    if (_position == DecorationPosition.background) {
      _paintDecoration(canvas, offset);
      if (child != null) {
        final BoxParentData childParentData =
            child!.parentData as BoxParentData;
        child!.paintWithContext(canvas, offset + childParentData.offset);
      }
    } else {
      if (child != null) {
        final BoxParentData childParentData =
            child!.parentData as BoxParentData;
        child!.paintWithContext(canvas, offset + childParentData.offset);
      }
      _paintDecoration(canvas, offset);
    }
  }

  @override
  bool hitTestChildren(HitTestResult result, {required Offset position}) {
    if (child != null) {
      final BoxParentData childParentData = child!.parentData as BoxParentData;
      final childPosition = position - childParentData.offset;
      return child!.hitTest(result, position: childPosition);
    }
    return false;
  }
}

/// Border characters for different styles
class _BorderCharacters {
  const _BorderCharacters({
    required this.horizontal,
    required this.vertical,
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });

  final String horizontal;
  final String vertical;
  final String topLeft;
  final String topRight;
  final String bottomLeft;
  final String bottomRight;

  static const single = _BorderCharacters(
    horizontal: '─',
    vertical: '│',
    topLeft: '┌',
    topRight: '┐',
    bottomLeft: '└',
    bottomRight: '┘',
  );

  static const double = _BorderCharacters(
    horizontal: '═',
    vertical: '║',
    topLeft: '╔',
    topRight: '╗',
    bottomLeft: '╚',
    bottomRight: '╝',
  );

  static const rounded = _BorderCharacters(
    horizontal: '─',
    vertical: '│',
    topLeft: '╭',
    topRight: '╮',
    bottomLeft: '╰',
    bottomRight: '╯',
  );

  static const dashed = _BorderCharacters(
    horizontal: '╌',
    vertical: '╎',
    topLeft: '┌',
    topRight: '┐',
    bottomLeft: '└',
    bottomRight: '┘',
  );

  static const dotted = _BorderCharacters(
    horizontal: '┅',
    vertical: '┇',
    topLeft: '┌',
    topRight: '┐',
    bottomLeft: '└',
    bottomRight: '┘',
  );
}

/// Position of the decoration relative to the child
enum DecorationPosition {
  background,
  foreground,
}

/// Widget that paints a decoration either before or after its child
class DecoratedBox extends SingleChildRenderObjectComponent {
  const DecoratedBox({
    super.key,
    required this.decoration,
    this.position = DecorationPosition.background,
    super.child,
  });

  final BoxDecoration decoration;
  final DecorationPosition position;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderDecoratedBox(
      decoration: decoration,
      position: position,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderDecoratedBox renderObject) {
    renderObject
      ..decoration = decoration
      ..position = position;
  }
}

/// Simplified Container widget that uses the new DecoratedBox
class Container extends StatelessComponent {
  const Container({
    super.key,
    this.alignment,
    this.padding,
    this.color,
    this.decoration,
    this.foregroundDecoration,
    this.width,
    this.height,
    this.constraints,
    this.margin,
    this.transform,
    this.child,
  });

  final Component? child;
  final AlignmentGeometry? alignment;
  final EdgeInsets? padding;
  final Color? color;
  final BoxDecoration? decoration;
  final BoxDecoration? foregroundDecoration;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final EdgeInsets? margin;
  final Matrix4? transform;

  @override
  Component build(BuildContext context) {
    Component? current = child;

    if (child == null &&
        (constraints == null ||
            !constraints!.hasBoundedWidth ||
            !constraints!.hasBoundedHeight)) {
      current = const LimitedBox(
        maxWidth: 0.0,
        maxHeight: 0.0,
      );
    }

    if (alignment != null) {
      current = Align(alignment: alignment!, child: current);
    }

    if (padding != null) {
      current = Padding(padding: padding!, child: current);
    }

    if (decoration != null || color != null) {
      current = DecoratedBox(
        decoration: decoration ?? BoxDecoration(color: color),
        child: current,
      );
    }

    if (foregroundDecoration != null) {
      current = DecoratedBox(
        decoration: foregroundDecoration!,
        position: DecorationPosition.foreground,
        child: current,
      );
    }

    if (constraints != null) {
      current = ConstrainedBox(constraints: constraints!, child: current);
    }

    if (width != null || height != null) {
      current = SizedBox(width: width, height: height, child: current);
    }

    if (margin != null) {
      current = Padding(padding: margin!, child: current);
    }

    if (transform != null) {
      current = Transform(transform: transform!, child: current);
    }

    return current!;
  }
}
