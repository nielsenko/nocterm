import 'package:nocterm/nocterm.dart' hide TextAlign;
import 'package:nocterm/src/framework/terminal_canvas.dart';
import 'package:nocterm/src/painting/inline_span.dart';

import '../text/text_layout_engine.dart';
export '../text/text_layout_engine.dart' show TextOverflow, TextAlign;

/// Render object for displaying rich text (text with multiple styles).
/// 
/// This is similar to RenderText but supports TextSpan with mixed styles.
class RenderParagraph extends RenderObject {
  RenderParagraph({
    required InlineSpan text,
    TextAlign textAlign = TextAlign.left,
    bool softWrap = true,
    TextOverflow overflow = TextOverflow.clip,
    int? maxLines,
  })  : _text = text,
        _textAlign = textAlign,
        _softWrap = softWrap,
        _overflow = overflow,
        _maxLines = maxLines;

  InlineSpan _text;
  InlineSpan get text => _text;
  set text(InlineSpan value) {
    if (_text == value) return;
    _text = value;
    _cachedSegments = null;
    markNeedsLayout();
  }

  TextAlign _textAlign;
  TextAlign get textAlign => _textAlign;
  set textAlign(TextAlign value) {
    if (_textAlign == value) return;
    _textAlign = value;
    markNeedsPaint();
  }

  bool _softWrap;
  bool get softWrap => _softWrap;
  set softWrap(bool value) {
    if (_softWrap == value) return;
    _softWrap = value;
    markNeedsLayout();
  }

  TextOverflow _overflow;
  TextOverflow get overflow => _overflow;
  set overflow(TextOverflow value) {
    if (_overflow == value) return;
    _overflow = value;
    markNeedsLayout();
  }

  int? _maxLines;
  int? get maxLines => _maxLines;
  set maxLines(int? value) {
    if (_maxLines == value) return;
    _maxLines = value;
    markNeedsLayout();
  }

  // Cache the styled segments to avoid recomputing them
  List<StyledTextSegment>? _cachedSegments;
  
  // Store the layout result and the styled lines
  TextLayoutResult? _layoutResult;
  List<List<StyledTextSegment>>? _styledLines;

  List<StyledTextSegment> get _segments {
    _cachedSegments ??= _text.toStyledSegments();
    return _cachedSegments!;
  }

  @override
  void performLayout() {
    final maxWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth.toInt()
        : double.maxFinite.toInt();

    // Get the plain text for layout calculation
    final plainText = _text.toPlainText();
    
    final config = TextLayoutConfig(
      softWrap: _softWrap,
      overflow: _overflow,
      textAlign: _textAlign,
      maxLines: _maxLines,
      maxWidth: maxWidth,
    );

    _layoutResult = TextLayoutEngine.layout(plainText, config);
    
    // Now map the styled segments to the laid out lines
    _styledLines = _mapSegmentsToLines(_segments, _layoutResult!.lines);
    
    size = constraints.constrain(Size(
      _layoutResult!.actualWidth.toDouble(),
      _layoutResult!.actualHeight.toDouble(),
    ));
  }

  /// Maps styled segments to the laid out lines.
  /// 
  /// This function takes the original styled segments and the lines produced
  /// by the layout engine, and creates a list of styled segments for each line.
  List<List<StyledTextSegment>> _mapSegmentsToLines(
    List<StyledTextSegment> segments,
    List<String> lines,
  ) {
    final List<List<StyledTextSegment>> styledLines = [];
    
    // Create a flattened string from all segments to match against laid out lines
    final StringBuffer fullTextBuffer = StringBuffer();
    for (final segment in segments) {
      fullTextBuffer.write(segment.text);
    }
    final String fullText = fullTextBuffer.toString();
    
    int textPos = 0; // Position in the full text
    int segmentIndex = 0;
    int segmentPos = 0;
    
    for (final String line in lines) {
      final List<StyledTextSegment> lineSegments = [];
      int linePos = 0;
      
      while (linePos < line.length && segmentIndex < segments.length) {
        var segment = segments[segmentIndex];
        
        // Skip to the next segment if we've consumed the current one
        while (segmentPos >= segment.text.length && segmentIndex < segments.length - 1) {
          segmentIndex++;
          segmentPos = 0;
          if (segmentIndex < segments.length) {
            segment = segments[segmentIndex];
          }
        }
        
        if (segmentIndex >= segments.length) break;
        
        // Calculate how much we can take from the current segment
        final remainingInSegment = segments[segmentIndex].text.length - segmentPos;
        final remainingInLine = line.length - linePos;
        
        if (remainingInSegment <= 0) {
          segmentIndex++;
          segmentPos = 0;
          continue;
        }
        
        final takeLength = remainingInSegment < remainingInLine 
            ? remainingInSegment 
            : remainingInLine;
        
        // Extract the text, making sure we're getting the right portion
        String text = segments[segmentIndex].text.substring(segmentPos, segmentPos + takeLength);
        
        // Check if this matches what we expect in the line
        final expectedText = line.substring(linePos, linePos + takeLength);
        if (text != expectedText) {
          // Handle case where newlines in segments don't match the laid out text
          // This can happen when newlines are present in the segments
          text = expectedText;
        }
        
        lineSegments.add(StyledTextSegment(text, segments[segmentIndex].style));
        
        segmentPos += takeLength;
        linePos += takeLength;
        textPos += takeLength;
        
        if (segmentPos >= segments[segmentIndex].text.length) {
          segmentIndex++;
          segmentPos = 0;
        }
      }
      
      styledLines.add(lineSegments);
      
      // After processing a line, skip any newlines in the source text
      while (textPos < fullText.length && 
             (fullText[textPos] == '\n' || 
              (textPos + 1 < fullText.length && line.length > 0 && fullText[textPos] == ' '))) {
        textPos++;
        // Also advance our segment tracking
        if (segmentIndex < segments.length) {
          while (segmentPos < segments[segmentIndex].text.length && 
                 (segments[segmentIndex].text[segmentPos] == '\n' || 
                  segments[segmentIndex].text[segmentPos] == ' ')) {
            segmentPos++;
            if (segmentPos >= segments[segmentIndex].text.length) {
              segmentIndex++;
              segmentPos = 0;
              if (segmentIndex >= segments.length) break;
            }
          }
        }
      }
    }
    
    return styledLines;
  }

  String get plainText => _text.toPlainText();

  @override
  void paint(TerminalCanvas canvas, Offset offset) {
    super.paint(canvas, offset);
    
    if (_layoutResult == null || _styledLines == null) return;
    
    final alignmentWidth = size.width.toInt();
    
    for (int i = 0; i < _styledLines!.length; i++) {
      final lineSegments = _styledLines![i];
      
      // Calculate the full line text for alignment
      final StringBuffer lineBuffer = StringBuffer();
      for (final segment in lineSegments) {
        lineBuffer.write(segment.text);
      }
      final lineText = lineBuffer.toString();
      
      // Apply justification if needed
      String displayLine = lineText;
      bool isLastLine = i == _styledLines!.length - 1;
      if (_textAlign == TextAlign.justify && !isLastLine) {
        displayLine = TextLayoutEngine.justifyLine(lineText, alignmentWidth, isLastLine: isLastLine);
      }
      
      // Calculate horizontal offset based on text alignment
      final xOffset = offset.dx + TextLayoutEngine.calculateAlignmentOffset(
        displayLine,
        alignmentWidth,
        _textAlign,
      );
      
      // Paint each segment with its style
      double currentX = xOffset;
      for (final segment in lineSegments) {
        canvas.drawText(
          Offset(currentX, offset.dy + i),
          segment.text,
          style: segment.style,
        );
        // Move x position by the width of the segment text
        // Note: This assumes monospace font where each character is 1 unit wide
        currentX += segment.text.length;
      }
    }
  }
}