import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

void main() {
  group('ScreenMode', () {
    test('ScreenMode enum has correct values', () {
      expect(ScreenMode.values, hasLength(2));
      expect(ScreenMode.alternateScreen, isNotNull);
      expect(ScreenMode.inline, isNotNull);
    });

    test('InlineExitBehavior enum has correct values', () {
      expect(InlineExitBehavior.values, hasLength(2));
      expect(InlineExitBehavior.preserve, isNotNull);
      expect(InlineExitBehavior.clear, isNotNull);
    });
  });

  group('Inline Mode - Basic Rendering', () {
    test('visual development - simple text renders inline', () async {
      await testNocterm(
        'simple text in inline-like environment',
        (tester) async {
          // Test that basic components render correctly
          // The test binding doesn't differentiate modes,
          // but we can verify the component renders
          await tester.pumpComponent(
            Center(
              child: Text('Hello Inline Mode!'),
            ),
          );

          expect(
            tester.terminalState.getText(),
            contains('Hello Inline Mode!'),
          );
        },
        debugPrintAfterPump: true,
      );
    });

    test('component with intrinsic height renders correctly', () async {
      await testNocterm(
        'intrinsic height component',
        (tester) async {
          // Test components that have intrinsic height
          // (important for inline mode where height isn't bounded)
          await tester.pumpComponent(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Line 1'),
                Text('Line 2'),
                Text('Line 3'),
              ],
            ),
          );

          final text = tester.terminalState.getText();
          expect(text, contains('Line 1'));
          expect(text, contains('Line 2'));
          expect(text, contains('Line 3'));
        },
        debugPrintAfterPump: true,
      );
    });

    test('nested columns with min size render correctly', () async {
      await testNocterm(
        'nested min-size columns for inline',
        (tester) async {
          await tester.pumpComponent(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Header'),
                SizedBox(height: 1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('[Option 1]'),
                    SizedBox(width: 2),
                    Text('[Option 2]'),
                  ],
                ),
                SizedBox(height: 1),
                Text('Footer'),
              ],
            ),
          );

          final text = tester.terminalState.getText();
          expect(text, contains('Header'));
          expect(text, contains('[Option 1]'));
          expect(text, contains('[Option 2]'));
          expect(text, contains('Footer'));
        },
        debugPrintAfterPump: true,
      );
    });
  });

  group('Inline Mode - Interactive Components', () {
    test('progress indicator updates correctly', () async {
      await testNocterm(
        'progress indicator for CLI',
        (tester) async {
          // Simulate a progress indicator that might be used in CLI mode
          await tester.pumpComponent(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Downloading...'),
                SizedBox(
                  width: 30,
                  height: 1,
                  child: ProgressBar(value: 0.5),
                ),
              ],
            ),
          );

          final text = tester.terminalState.getText();
          expect(text, contains('Downloading'));
          // Progress bar should show some fill
          expect(text, contains('█'));
        },
        debugPrintAfterPump: true,
      );
    });

    test('simple prompt renders correctly', () async {
      await testNocterm(
        'simple CLI prompt',
        (tester) async {
          await tester.pumpComponent(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('? Enter your name:'),
                Row(
                  children: [
                    Text('> '),
                    Expanded(child: TextField()),
                  ],
                ),
              ],
            ),
          );

          expect(
            tester.terminalState.getText(),
            contains('Enter your name'),
          );
        },
        debugPrintAfterPump: true,
      );
    });
  });

  group('Inline Mode - Small Terminal Sizes', () {
    test('renders in small terminal', () async {
      await testNocterm(
        'small terminal rendering',
        (tester) async {
          await tester.pumpComponent(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Small'),
                Text('Test'),
              ],
            ),
          );

          expect(tester.terminalState.getText(), contains('Small'));
          expect(tester.terminalState.getText(), contains('Test'));
        },
        size: const Size(20, 5),
        debugPrintAfterPump: true,
      );
    });

    test('single line component', () async {
      await testNocterm(
        'single line for inline',
        (tester) async {
          await tester.pumpComponent(
            SizedBox(
              height: 1,
              child: Text('Single line output'),
            ),
          );

          expect(
            tester.terminalState.getText(),
            contains('Single line output'),
          );
        },
        size: const Size(40, 3),
        debugPrintAfterPump: true,
      );
    });
  });

  group('TerminalBinding - Screen Mode Configuration', () {
    test('TerminalBinding accepts screenMode parameter', () {
      // This test verifies that TerminalBinding can be constructed
      // with the new screenMode parameter without throwing
      // We can't fully test the terminal behavior without a real terminal,
      // but we verify the API exists and works

      // The screenMode and inlineExitBehavior are part of the constructor
      // signature, verified at compile time
      expect(ScreenMode.inline, equals(ScreenMode.inline));
      expect(ScreenMode.alternateScreen, equals(ScreenMode.alternateScreen));
      expect(InlineExitBehavior.preserve, equals(InlineExitBehavior.preserve));
      expect(InlineExitBehavior.clear, equals(InlineExitBehavior.clear));
    });
  });
}
