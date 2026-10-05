import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

RenderListViewport _findViewport() {
  RenderListViewport? viewport;
  void visit(Element element) {
    if (element is RenderObjectElement &&
        element.renderObject is RenderListViewport) {
      viewport = element.renderObject as RenderListViewport;
      return;
    }
    element.visitChildren(visit);
  }

  visit(NoctermTestBinding.instance.rootElement!);
  return viewport!;
}

void main() {
  group('RenderListViewport item geometry', () {
    test('a lazy list answers for the rows around its viewport', () async {
      await testNocterm('lazy geometry', (tester) async {
        final controller = ScrollController();
        await tester.pumpComponent(
          Container(
            width: 20,
            height: 5,
            child: ListView.builder(
              controller: controller,
              itemCount: 1000,
              lazy: true,
              itemBuilder: (context, index) => Text('Item$index'),
            ),
          ),
        );
        controller.jumpTo(500);
        await tester.pump();

        final viewport = _findViewport();
        final (first, last) = viewport.laidOutItemRange!;
        expect(first, lessThanOrEqualTo(500));
        expect(last, greaterThanOrEqualTo(504));
        expect(last, lessThan(999));

        for (var index = first; index <= last; index++) {
          expect(
            viewport.getItemOffsetAndExtent(index),
            (index.toDouble(), 1.0),
          );
        }
        expect(viewport.getItemOffsetAndExtent(first - 1), isNull);
        expect(viewport.getItemOffsetAndExtent(last + 1), isNull);
      });
    });

    test('separators stay out of the item indices', () async {
      await testNocterm('separated geometry', (tester) async {
        await tester.pumpComponent(
          Container(
            width: 20,
            height: 6,
            child: ListView.separated(
              itemCount: 3,
              itemBuilder: (context, index) => Text('Item$index'),
              separatorBuilder: (context, index) => Text('-'),
            ),
          ),
        );

        final viewport = _findViewport();
        expect(viewport.laidOutItemRange, (0, 2));
        expect(viewport.getItemOffsetAndExtent(0), (0.0, 1.0));
        expect(viewport.getItemOffsetAndExtent(1), (2.0, 1.0));
        expect(viewport.getItemOffsetAndExtent(2), (4.0, 1.0));
      });
    });

    test('an empty list has no laid-out range', () async {
      await testNocterm('empty geometry', (tester) async {
        await tester.pumpComponent(
          Container(
            width: 20,
            height: 5,
            child: ListView.builder(
              itemCount: 0,
              itemBuilder: (context, index) => Text('Item$index'),
            ),
          ),
        );

        final viewport = _findViewport();
        expect(viewport.laidOutItemRange, isNull);
        expect(viewport.getItemOffsetAndExtent(0), isNull);
      });
    });
  });
}
