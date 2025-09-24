import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';
import '../example/changing_test.dart';

void main() {
  group('ChangingTest Bug Reproduction', () {
    test('switching between Expanded and Text should not accumulate items', () async {
      await testNocterm(
        'bug reproduction',
        (tester) async {
          await tester.pumpComponent(const ChangingTest());

          print('\n=== Initial state (showing "two") ===');
          tester.terminalState.toString();

          // Toggle to show Expanded with "one"
          await tester.sendKey(LogicalKey.space);
          await tester.pump();
          print('\n=== After first toggle (showing Expanded with "one") ===');
          tester.terminalState.toString();

          // Toggle back to show "two"
          await tester.sendKey(LogicalKey.space);
          await tester.pump();
          print('\n=== After second toggle (back to "two") ===');
          tester.terminalState.toString();

          // Toggle again to Expanded
          await tester.sendKey(LogicalKey.space);
          await tester.pump();
          print('\n=== After third toggle (Expanded again) ===');
          tester.terminalState.toString();

          // Toggle back one more time
          await tester.sendKey(LogicalKey.space);
          await tester.pump();
          print('\n=== After fourth toggle (back to "two" again) ===');
          tester.terminalState.toString();

          // Continue toggling to see if items accumulate
          for (int i = 0; i < 4; i++) {
            await tester.sendKey(LogicalKey.space);
            await tester.pump();
            print('\n=== After toggle ${i + 5} ===');
            print(tester.renderToString());
          }
        },
        size: Size(40, 20),
      );
    });

    test('visual inspection of the bug', () async {
      await testNocterm(
        'visual bug test',
        (tester) async {
          await tester.pumpComponent(const ChangingTest());

          // Initial state
          print('Initial (Text "two"):');
          print(tester.renderToString());

          // Toggle multiple times to see accumulation
          for (int i = 1; i <= 10; i++) {
            await tester.sendKey(LogicalKey.space);
            await tester.pump();

            String expectedState = i % 2 == 1 ? 'Expanded "one"' : 'Text "two"';
            print('\nAfter toggle $i ($expectedState):');

            // Count occurrences of "one" and "two"
            var state = tester.terminalState.toString();
            var oneCount = 'one'.allMatches(state).length;
            var twoCount = 'two'.allMatches(state).length;

            print('Occurrences - "one": $oneCount, "two": $twoCount');
            print(tester.renderToString());

            if (oneCount > 1 || twoCount > 1) {
              print('BUG DETECTED: Text is being duplicated!');
            }
          }
        },
        size: Size(40, 10),
      );
    });
  });
}
