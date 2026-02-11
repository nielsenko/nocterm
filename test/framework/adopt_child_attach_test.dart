import 'package:nocterm/nocterm.dart' hide isEmpty, isNotEmpty;
import 'package:test/test.dart';

/// Regression test for adoptChild not calling attach() on the child when
/// the parent is already attached to a PipelineOwner.
///
/// In Flutter, RenderObject.adoptChild() calls child.attach(owner) when the
/// parent is already attached. Without this, render objects inserted into an
/// already-attached parent (e.g., after element tree reparenting) never get
/// their owner set. This breaks features like GestureDetector that create
/// mouse annotations in attach().
void main() {
  group('adoptChild propagates attach to children', () {
    test('child gets owner when adopted by attached parent', () {
      final owner = PipelineOwner();
      final parent = _TestContainer();
      parent.attach(owner);

      expect(parent.owner, equals(owner));

      // Adopt a child into the already-attached parent
      final child = _TestRenderObject();
      expect(child.owner, isNull);

      parent.adoptChild(child);

      // Child must now be attached to the same owner
      expect(child.owner, equals(owner),
          reason: 'adoptChild must call attach() on the child when the '
              'parent is already attached to a PipelineOwner');
    });

    test('grandchild gets owner when adopted transitively', () {
      final owner = PipelineOwner();
      final parent = _TestContainer();
      parent.attach(owner);

      // Create a container child with its own grandchild already set
      final child = _TestContainer();
      final grandchild = _TestRenderObject();
      // Set grandchild on child before adopting into parent.
      // At this point child has no owner, so grandchild also has no owner.
      child.testChild = grandchild;
      expect(child.owner, isNull);
      expect(grandchild.owner, isNull);

      // Now adopt child into the attached parent
      parent.adoptChild(child);

      // Both child and grandchild must be attached
      expect(child.owner, equals(owner), reason: 'child must be attached');
      expect(grandchild.owner, equals(owner),
          reason: 'grandchild must be attached transitively');
    });

    test('child does not get attached when parent has no owner', () {
      final parent = _TestContainer();
      final child = _TestRenderObject();

      parent.adoptChild(child);

      // Neither should have an owner
      expect(parent.owner, isNull);
      expect(child.owner, isNull);
      // But parent should be set
      expect(child.parent, equals(parent));
    });

    test('ContainerRenderObjectMixin.insert attaches child', () {
      final owner = PipelineOwner();
      final parent = _TestFlex();
      parent.attach(owner);

      final child = _TestRenderObject();
      parent.insert(child);

      expect(child.owner, equals(owner),
          reason: 'insert calls adoptChild which must propagate attach');
    });

    test('RenderObjectWithChildMixin set child attaches child', () {
      final owner = PipelineOwner();
      final parent = _TestSingleChild();
      parent.attach(owner);

      final child = _TestRenderObject();
      parent.child = child;

      expect(child.owner, equals(owner),
          reason: 'setting child must propagate attach');
    });
  });
}

// ---------------------------------------------------------------------------
// Minimal test render objects
// ---------------------------------------------------------------------------

class _TestRenderObject extends RenderObject {
  @override
  void performLayout() {
    size = constraints.constrain(const Size(10, 1));
  }
}

/// A render object with ContainerRenderObjectMixin for testing insert().
class _TestFlex extends RenderObject
    with ContainerRenderObjectMixin<RenderObject> {
  @override
  void performLayout() {
    size = constraints.constrain(const Size(10, 1));
  }
}

/// A render object with RenderObjectWithChildMixin for testing set child.
class _TestSingleChild extends RenderObject
    with RenderObjectWithChildMixin<RenderObject> {
  @override
  void performLayout() {
    size = constraints.constrain(const Size(10, 1));
  }
}

/// A container that manually manages a single child via attach/detach,
/// similar to how RenderListViewport works.
class _TestContainer extends RenderObject {
  _TestRenderObject? _testChild;

  set testChild(_TestRenderObject? value) {
    _testChild = value;
    if (value != null) {
      adoptChild(value);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _testChild?.attach(owner);
  }

  @override
  void detach() {
    _testChild?.detach();
    super.detach();
  }

  @override
  void performLayout() {
    size = constraints.constrain(const Size(10, 1));
  }
}
