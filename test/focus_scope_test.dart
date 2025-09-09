import 'package:test/test.dart';
import 'package:nocterm/nocterm.dart';

void main() {
  group('FocusScope', () {
    test('disables focus in background when modal is shown', () async {
      await testNocterm(
        'focus scope test',
        (tester) async {
          print('\n=== Testing Focus Scope ===\n');
          
          // Track which component has focus
          String focusedComponent = 'none';
          
          final navigator = TuiNavigator(
            home: Container(
              padding: const EdgeInsets.all(2),
              child: Column(
                children: [
                  const Text('Main Page'),
                  const SizedBox(height: 1),
                  // This should be focusable when no modal is shown
                  KeyboardListener(
                    onKeyEvent: (key) {
                      if (key == LogicalKey.keyA) {
                        focusedComponent = 'main';
                        print('Main page received key A');
                      }
                    },
                    autofocus: true,
                    child: const Text('Press A to test focus on main page'),
                  ),
                ],
              ),
            ),
          );
          
          await tester.pumpComponent(navigator);
          final navState = tester.findState<NavigatorState>();
          
          print('Testing focus on main page...');
          await tester.sendKey(LogicalKey.keyA);
          await tester.pump();
          expect(focusedComponent, 'main', reason: 'Main page should receive focus events');
          
          // Reset
          focusedComponent = 'none';
          
          print('\nShowing dialog...');
          navState.showDialog<void>(
            builder: (context) => Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                border: BoxBorder.all(),
              ),
              child: KeyboardListener(
                onKeyEvent: (key) {
                  if (key == LogicalKey.keyB) {
                    focusedComponent = 'dialog';
                    print('Dialog received key B');
                  }
                },
                autofocus: true,
                child: const Text('Dialog - Press B to test focus'),
              ),
            ),
            width: 30,
            height: 8,
          );
          
          await tester.pump();
          
          print('\nTesting focus with dialog open...');
          
          // Test that dialog receives focus
          await tester.sendKey(LogicalKey.keyB);
          await tester.pump();
          expect(focusedComponent, 'dialog', reason: 'Dialog should receive focus events');
          
          // Reset
          focusedComponent = 'none';
          
          // Test that main page does NOT receive focus
          await tester.sendKey(LogicalKey.keyA);
          await tester.pump();
          expect(focusedComponent, 'none', reason: 'Main page should NOT receive focus when dialog is open');
          
          print('\nClosing dialog...');
          navState.pop();
          await tester.pump();
          
          // Test that main page receives focus again
          await tester.sendKey(LogicalKey.keyA);
          await tester.pump();
          expect(focusedComponent, 'main', reason: 'Main page should receive focus after dialog is closed');
        },
        debugPrintAfterPump: false,
      );
    });
    
    test('FocusScope basic functionality', () async {
      await testNocterm(
        'focus scope basic test',
        (tester) async {
          // Test that FocusScope wraps content correctly
          await tester.pumpComponent(
            FocusScope(
              enabled: false,
              child: const Text('Disabled Focus'),
            ),
          );
          
          expect(tester.terminalState, containsText('Disabled Focus'));
          
          // Test with enabled focus
          await tester.pumpComponent(
            const FocusScope(
              enabled: true,
              child: Text('Enabled Focus'),
            ),
          );
          
          expect(tester.terminalState, containsText('Enabled Focus'));
        },
      );
    });
    
    test('multiple modals disable focus on lower layers', () async {
      await testNocterm(
        'multiple modals focus test',
        (tester) async {
          final navigator = TuiNavigator(
            home: const Text('Home'),
          );
          
          await tester.pumpComponent(navigator);
          final navState = tester.findState<NavigatorState>();
          
          // Show first dialog
          navState.showDialog<void>(
            builder: (context) => const Text('Dialog 1'),
            width: 20,
            height: 5,
          );
          await tester.pump();
          
          // Show second dialog on top
          navState.showDialog<void>(
            builder: (context) => const Text('Dialog 2'),
            width: 15,
            height: 5,
          );
          await tester.pump();
          
          // Both dialogs should be visible but only the top one should have focus
          expect(tester.terminalState, containsText('Dialog 2'));
          
          // Close top dialog
          navState.pop();
          await tester.pump();
          
          // First dialog should be visible
          expect(tester.terminalState, containsText('Dialog 1'));
          expect(tester.terminalState, isNot(containsText('Dialog 2')));
        },
      );
    });
  });
}