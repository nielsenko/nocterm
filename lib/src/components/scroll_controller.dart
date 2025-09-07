import 'package:nocterm/nocterm.dart';

/// Controls a scrollable widget.
///
/// Manages the scroll position and provides methods to programmatically
/// control scrolling.
class ScrollController extends ChangeNotifier {
  ScrollController({
    double initialScrollOffset = 0.0,
  }) : _offset = initialScrollOffset;

  double _offset;
  double _minScrollExtent = 0.0;
  double _maxScrollExtent = 0.0;
  double _viewportDimension = 0.0;

  /// The current scroll offset.
  double get offset => _offset;

  /// The minimum in-range value for [offset].
  double get minScrollExtent => _minScrollExtent;

  /// The maximum in-range value for [offset].
  double get maxScrollExtent => _maxScrollExtent;

  /// The extent of the viewport in the scrolling direction.
  double get viewportDimension => _viewportDimension;

  /// Whether the [offset] is at the minimum value.
  bool get atStart => offset <= minScrollExtent;

  /// Whether the [offset] is at the maximum value.
  bool get atEnd => offset >= maxScrollExtent;

  /// The total scrollable extent.
  double get scrollExtent => maxScrollExtent - minScrollExtent;

  /// Updates the scroll metrics.
  void updateMetrics({
    required double minScrollExtent,
    required double maxScrollExtent,
    required double viewportDimension,
  }) {
    final oldMin = _minScrollExtent;
    final oldMax = _maxScrollExtent;
    final oldViewport = _viewportDimension;
    final oldOffset = _offset;
    
    _minScrollExtent = minScrollExtent;
    _maxScrollExtent = maxScrollExtent;
    _viewportDimension = viewportDimension;

    // Clamp the current offset to valid range
    _offset = _offset.clamp(minScrollExtent, maxScrollExtent);
    
    // Only notify listeners if something actually changed
    if (oldMin != _minScrollExtent ||
        oldMax != _maxScrollExtent ||
        oldViewport != _viewportDimension ||
        oldOffset != _offset) {
      notifyListeners();
    }
  }

  /// Jumps the scroll position to the given value.
  void jumpTo(double value) {
    _offset = value.clamp(minScrollExtent, maxScrollExtent);
    notifyListeners();
  }

  /// Scrolls by the given delta.
  void scrollBy(double delta) {
    jumpTo(offset + delta);
  }

  /// Scrolls up by one line (for TUI).
  void scrollUp([double lines = 1.0]) {
    scrollBy(-lines);
  }

  /// Scrolls down by one line (for TUI).
  void scrollDown([double lines = 1.0]) {
    scrollBy(lines);
  }

  /// Scrolls up by one page.
  void pageUp() {
    scrollBy(-viewportDimension);
  }

  /// Scrolls down by one page.
  void pageDown() {
    scrollBy(viewportDimension);
  }

  /// Scrolls to the start.
  void scrollToStart() {
    jumpTo(minScrollExtent);
  }

  /// Scrolls to the end.
  void scrollToEnd() {
    jumpTo(maxScrollExtent);
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// Base class for change notification.
abstract class ChangeNotifier {
  final List<VoidCallback> _listeners = [];

  /// Register a closure to be called when the object notifies its listeners.
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove a previously registered listener.
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Call all registered listeners.
  void notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Discards any resources used by the object.
  void dispose() {
    _listeners.clear();
  }
}
