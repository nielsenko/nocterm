import 'package:nocterm/src/framework/framework.dart';
import 'package:nocterm/src/framework/terminal_canvas.dart';
import 'package:nocterm/src/size.dart';

/// Signature for a function that builds a component given a [BuildContext]
/// and the parent's [BoxConstraints].
typedef LayoutWidgetBuilder = Component Function(
  BuildContext context,
  BoxConstraints constraints,
);

/// Builds a component tree that can depend on the parent component's size.
///
/// Similar to the [Builder] component except that the framework calls the
/// [builder] function at layout time and provides the parent component's
/// constraints. This is useful when the parent constrains the child's size
/// and doesn't depend on the child's intrinsic size.
///
/// The [LayoutBuilder]'s final size will match its child's size.
///
/// The [builder] function is called in the following situations:
///
/// * The first time the component is laid out.
/// * When the parent component passes different layout constraints.
/// * When the parent component updates this component.
/// * When the dependencies that the [builder] function subscribes to change.
///
/// Example:
/// ```dart
/// LayoutBuilder(
///   builder: (context, constraints) {
///     if (constraints.maxWidth > 80) {
///       return Text('Wide layout');
///     } else {
///       return Text('Narrow layout');
///     }
///   },
/// )
/// ```
class LayoutBuilder extends RenderObjectComponent {
  /// Creates a component that defers its building until layout.
  const LayoutBuilder({super.key, required this.builder});

  /// Called at layout time to construct the component tree.
  ///
  /// The builder is passed the [BoxConstraints] that the parent is
  /// providing to this component. Use these constraints to determine
  /// which child component to build.
  final LayoutWidgetBuilder builder;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderLayoutBuilder();
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderLayoutBuilder renderObject,
  ) {
    // RenderObject doesn't store any widget properties,
    // the callback is updated via the element
  }

  @override
  _LayoutBuilderElement createElement() => _LayoutBuilderElement(this);
}

/// Element for [LayoutBuilder] that handles rebuilding during layout.
class _LayoutBuilderElement extends SingleChildRenderObjectElement {
  _LayoutBuilderElement(LayoutBuilder super.component);

  @override
  LayoutBuilder get component => super.component as LayoutBuilder;

  @override
  _RenderLayoutBuilder get renderObject =>
      super.renderObject as _RenderLayoutBuilder;

  Element? _child;

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_child != null) {
      visitor(_child!);
    }
  }

  @override
  void forgetChild(Element child) {
    assert(child == _child);
    _child = null;
    super.forgetChild(child);
  }

  @override
  void mount(Element? parent, dynamic newSlot) {
    super.mount(parent, newSlot);
    // Register our callback with the render object
    renderObject._updateCallback(_rebuildWithConstraints);
  }

  @override
  void update(Component newComponent) {
    super.update(newComponent);
    // Re-register callback and schedule rebuild
    renderObject._updateCallback(_rebuildWithConstraints);
    // Clear previous constraints to force rebuild
    renderObject._previousConstraints = null;
    renderObject.markNeedsLayout();
  }

  @override
  void performRebuild() {
    // Force the callback to be called during the next layout pass
    renderObject._previousConstraints = null;
    renderObject.markNeedsLayout();
    // Let the base class handle marking as not dirty
    super.performRebuild();
  }

  @override
  void unmount() {
    renderObject._callback = null;
    super.unmount();
  }

  /// Called by the render object during layout to rebuild the child.
  void _rebuildWithConstraints(BoxConstraints constraints) {
    // Build the child with the new constraints
    final Component built = component.builder(this, constraints);
    _child = updateChild(_child, built, null);
  }

  @override
  void insertRenderObjectChild(RenderObject child, dynamic slot) {
    final _RenderLayoutBuilder renderObject = this.renderObject;
    assert(slot == null);
    renderObject.child = child;
  }

  @override
  void moveRenderObjectChild(
    RenderObject child,
    dynamic oldSlot,
    dynamic newSlot,
  ) {
    // LayoutBuilder has only one child, so this should never be called
    assert(false, 'LayoutBuilder should never move children');
  }

  @override
  void removeRenderObjectChild(RenderObject child, dynamic slot) {
    final _RenderLayoutBuilder renderObject = this.renderObject;
    assert(renderObject.child == child);
    renderObject.child = null;
  }
}

/// The render object for [LayoutBuilder].
///
/// This render object invokes a callback during layout that allows the
/// element to rebuild its child with the current constraints.
class _RenderLayoutBuilder extends RenderObject
    with RenderObjectWithChildMixin<RenderObject> {
  /// The callback that is invoked during layout to rebuild the child.
  void Function(BoxConstraints constraints)? _callback;

  /// The constraints from the previous layout pass.
  BoxConstraints? _previousConstraints;

  /// Update the layout callback.
  void _updateCallback(void Function(BoxConstraints constraints) value) {
    if (value == _callback) {
      return;
    }
    _callback = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  @override
  void performLayout() {
    // Always invoke the callback when constraints have changed
    // This ensures LayoutBuilder rebuilds on terminal resize
    if (_callback != null && constraints != _previousConstraints) {
      _callback!(constraints);
      _previousConstraints = constraints;
    }

    // Now layout the child
    if (child != null) {
      child!.layout(constraints, parentUsesSize: true);
      size = constraints.constrain(child!.size);
    } else {
      // If no child (shouldn't happen normally), take the max size
      size = constraints.constrain(Size.zero);
    }
  }

  @override
  void paint(TerminalCanvas canvas, Offset offset) {
    super.paint(canvas, offset);
    if (child != null) {
      final BoxParentData childParentData = child!.parentData as BoxParentData;
      child!.paint(canvas, offset + childParentData.offset);
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
