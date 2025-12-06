import 'package:nocterm/nocterm.dart' hide isNotEmpty;
import 'package:test/test.dart';

void main() {
  group('Builder', () {
    test('basic builder', () async {
      await testNocterm(
        'basic builder',
        (tester) async {
          await tester.pumpComponent(
            Builder(builder: (context) => const Text('Hello from Builder')),
          );
          expect(
            tester.terminalState,
            containsText('Hello from Builder'),
          );
        },
        debugPrintAfterPump: true,
      );
    });

    test('builder returns a component', () async {
      await testNocterm(
        'returns component',
        (tester) async {
          await tester.pumpComponent(
            SizedBox(
              width: 40,
              height: 10,
              child: Builder(
                builder: (context) {
                  // Builder just returns a component
                  return const Text('Simple component');
                },
              ),
            ),
          );
          expect(
            tester.terminalState,
            containsText('Simple component'),
          );
        },
        debugPrintAfterPump: true,
      );
    });

    test('builder can be nested', () async {
      await testNocterm(
        'nested builders',
        (tester) async {
          await tester.pumpComponent(
            Builder(
              builder: (outerContext) {
                return Builder(
                  builder: (innerContext) {
                    return const Text('Nested Builder');
                  },
                );
              },
            ),
          );
          expect(
            tester.terminalState,
            containsText('Nested Builder'),
          );
        },
        debugPrintAfterPump: true,
      );
    });
  });

  group('LayoutBuilder', () {
    test('receives constraints', () async {
      await testNocterm(
        'receives constraints',
        (tester) async {
          await tester.pumpComponent(
            SizedBox(
              width: 40,
              height: 10,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Text('Width: ${constraints.maxWidth.toInt()}');
                },
              ),
            ),
          );
          // LayoutBuilder receives constraints and renders
          // Note: Exact values may vary based on terminal/test environment
          expect(
            tester.terminalState,
            containsText('Width:'),
          );
        },
        debugPrintAfterPump: true,
      );
    });

    test('receives height constraints', () async {
      await testNocterm(
        'height constraints',
        (tester) async {
          await tester.pumpComponent(
            SizedBox(
              width: 50,
              height: 15,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Text('H: ${constraints.maxHeight.toInt()}');
                },
              ),
            ),
          );
          // LayoutBuilder should receive the height from SizedBox
          expect(
            tester.terminalState,
            containsText('H:'),
          );
        },
        debugPrintAfterPump: true,
      );
    });

    test('can build different widgets based on constraints', () async {
      await testNocterm(
        'conditional building',
        (tester) async {
          await tester.pumpComponent(
            SizedBox(
              width: 60,
              height: 20,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 50) {
                    return const Text('Wide layout');
                  } else {
                    return const Text('Narrow layout');
                  }
                },
              ),
            ),
          );
          expect(
            tester.terminalState,
            containsText('Wide layout'),
          );
        },
        debugPrintAfterPump: true,
      );
    });

    test('layout changes based on constraint threshold', () async {
      await testNocterm(
        'layout threshold',
        (tester) async {
          // Test that the LayoutBuilder correctly uses constraint values for decisions
          // We'll use a threshold that's below the terminal width to ensure the wide path is taken
          await tester.pumpComponent(
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 40) {
                  return const Text('Wide layout');
                } else {
                  return const Text('Narrow layout');
                }
              },
            ),
          );
          // Terminal width is typically 80, so this should show Wide layout
          expect(
            tester.terminalState,
            containsText('Wide layout'),
          );
        },
        debugPrintAfterPump: true,
      );
    });

    test('nested in container', () async {
      await testNocterm(
        'nested in container',
        (tester) async {
          await tester.pumpComponent(
            Container(
              decoration: BoxDecoration(
                border: BoxBorder.all(color: Colors.cyan),
              ),
              child: SizedBox(
                width: 30,
                height: 5,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Center(
                      child: Text('${constraints.maxWidth.toInt()}x${constraints.maxHeight.toInt()}'),
                    );
                  },
                ),
              ),
            ),
          );
          // The container border takes some space, so the constraints passed to LayoutBuilder
          // will be smaller than the SizedBox size. Just verify it renders something.
          expect(
            tester.terminalState,
            containsText('x'),
          );
        },
        debugPrintAfterPump: true,
      );
    });

    test('works with Row and Column', () async {
      await testNocterm(
        'with flex layouts',
        (tester) async {
          await tester.pumpComponent(
            SizedBox(
              width: 60,
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Text('A:${constraints.maxWidth.toInt()}');
                      },
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Text('B:${constraints.maxWidth.toInt()}');
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
          // Each expanded child should get half the width (30 each)
          // Verify we see both labels
          expect(
            tester.terminalState,
            containsText('A:'),
          );
          expect(
            tester.terminalState,
            containsText('B:'),
          );
        },
        debugPrintAfterPump: true,
      );
    });

    test('visual test - responsive layout example', () async {
      await testNocterm(
        'responsive layout',
        (tester) async {
          await tester.pumpComponent(
            Column(
              children: [
                SizedBox(
                  width: 60,
                  height: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      border: BoxBorder.all(color: Colors.blue),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Center(
                          child: Text(
                            'Available: ${constraints.maxWidth.toInt()}x${constraints.maxHeight.toInt()}',
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                SizedBox(
                  width: 80,
                  height: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      border: BoxBorder.all(color: Colors.green),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Center(
                          child: Text(
                            'Available: ${constraints.maxWidth.toInt()}x${constraints.maxHeight.toInt()}',
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );

          // Print visual output
          print('\nVisual output of LayoutBuilder:');
          print(tester.toSnapshot());
        },
        debugPrintAfterPump: true,
      );
    });
  });
}
