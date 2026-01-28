/// Global selection drag state used to coordinate behavior across widgets.
class SelectionDragState {
  static int _activeCount = 0;
  static final Map<Object, SelectionRange> _ranges = {};

  /// Whether a selection drag is currently active.
  static bool get isActive => _activeCount > 0;

  /// Mark selection drag as active.
  static void begin() {
    _activeCount++;
  }

  /// Mark selection drag as inactive.
  static void end() {
    if (_activeCount > 0) {
      _activeCount--;
    }
    if (_activeCount == 0) {
      _ranges.clear();
    }
  }

  static void updateRange(Object context, int minIndex, int maxIndex) {
    if (minIndex > maxIndex) return;
    _ranges[context] = SelectionRange(minIndex, maxIndex);
  }

  static SelectionRange? rangeFor(Object context) {
    return _ranges[context];
  }
}

class SelectionRange {
  SelectionRange(this.minIndex, this.maxIndex);

  final int minIndex;
  final int maxIndex;
}
