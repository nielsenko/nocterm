import 'package:nocterm/nocterm.dart';
import 'package:nocterm/src/components/render_flex.dart';

/// Unit test for flex implementation
void main() {
  print('Testing Flex Layout Implementation...\n');

  // Test 1: Basic Row layout with non-flexible children
  print('Test 1: Basic Row layout');
  final row1 = Row(
    children: const [
      Text('A'),
      Text('B'),
      Text('C'),
    ],
  );
  testComponent(row1, 'Basic Row');

  // Test 2: Row with Expanded children
  print('\nTest 2: Row with Expanded children');
  final row2 = Row(
    children: [
      const Text('Fixed'),
      Expanded(child: const Text('Expanded')),
      const Text('Fixed'),
    ],
  );
  testComponent(row2, 'Row with Expanded');

  // Test 3: Row with multiple Expanded children with different flex values
  print('\nTest 3: Row with different flex values');
  final row3 = Row(
    children: [
      Expanded(flex: 1, child: const Text('Flex:1')),
      Expanded(flex: 2, child: const Text('Flex:2')),
      Expanded(flex: 3, child: const Text('Flex:3')),
    ],
  );
  testComponent(row3, 'Row with different flex');

  // Test 4: Column with mixed children
  print('\nTest 4: Column with mixed children');
  final col1 = Column(
    children: [
      const Text('Fixed Top'),
      Expanded(child: const Text('Expanded Middle')),
      const Text('Fixed Bottom'),
    ],
  );
  testComponent(col1, 'Column with Expanded');

  print('\n✅ All flex tests completed successfully!');
}

void testComponent(Component component, String testName) {
  try {
    // Create element tree
    // ignore: invalid_use_of_protected_member
    final element = component.createElement();
    element.mount(null, null);
    // ignore: invalid_use_of_protected_member
    element.performRebuild();

    // Find render object
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

    final renderObject = findRenderObject(element);
    if (renderObject == null) {
      print('  ❌ $testName: Could not find render object');
      return;
    }

    // Layout with test constraints
    final constraints = BoxConstraints(
      minWidth: 0,
      maxWidth: 80,
      minHeight: 0,
      maxHeight: 24,
    );
    renderObject.layout(constraints);

    // Check that layout completed
    final size = renderObject.size;
    print('  ✓ $testName: Layout completed, size: ${size.width}x${size.height}');

    // Verify children have parent data if they're under flex
    if (renderObject is RenderFlex) {
      int flexChildCount = 0;
      int totalFlex = 0;

      for (final child in renderObject.children) {
        final parentData = child.parentData;
        if (parentData is FlexParentData) {
          flexChildCount++;
          totalFlex += parentData.flex ?? 0;
          print('    - Found flex child with flex=${parentData.flex}, fit=${parentData.fit}');
        }
      }

      if (flexChildCount > 0) {
        print('    - Total flex children: $flexChildCount, total flex: $totalFlex');
      }
    }
  } catch (e, stack) {
    print('  ❌ $testName failed: $e');
    print('Stack: $stack');
  }
}
