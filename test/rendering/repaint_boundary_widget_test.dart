import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

void main() {
  group('RepaintBoundary widget', () {
    test('renders its child', () async {
      await testNocterm('repaint boundary smoke', (tester) async {
        await tester.pumpComponent(
          const Center(child: RepaintBoundary(child: Text('Hello'))),
        );
        expect(tester.terminalState.getText(), contains('Hello'));
      }, size: const Size(40, 5));
    });

    test('child stays visible across pumps', () async {
      await testNocterm('repaint boundary persistence', (tester) async {
        await tester.pumpComponent(
          const RepaintBoundary(child: Text('Cached')),
        );
        await tester.pump();
        await tester.pump();
        expect(tester.terminalState.getText(), contains('Cached'));
      }, size: const Size(40, 5));
    });
  });
}
