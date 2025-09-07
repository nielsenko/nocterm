import 'package:nocterm/nocterm.dart';

void main() async {
  await runApp(const ScrollDemo());
}

class ScrollDemo extends StatefulComponent {
  const ScrollDemo({super.key});

  @override
  State<ScrollDemo> createState() => _ScrollDemoState();
}

class _ScrollDemoState extends State<ScrollDemo> {
  int selectedTab = 0;
  final scrollController1 = ScrollController();
  final scrollController2 = ScrollController();
  final scrollController3 = ScrollController();

  @override
  void dispose() {
    scrollController1.dispose();
    scrollController2.dispose();
    scrollController3.dispose();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.tab) {
          setState(() {
            selectedTab = (selectedTab + 1) % 4;
          });
          return true;
        }
        return false;
      },
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(1),
            decoration: BoxDecoration(
              border: BoxBorder.all(color: Colors.cyan),
            ),
            child: Center(
              child: Text(
                'Scroll Components Demo',
                style: TextStyle(color: Colors.brightCyan, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Tab navigation
          Container(
            padding: EdgeInsets.symmetric(vertical: 1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTab('SingleChildScrollView', 0),
                Text(' | '),
                _buildTab('ListView', 1),
                Text(' | '),
                _buildTab('ListView.builder', 2),
                Text(' | '),
                _buildTab('With Scrollbar', 3),
              ],
            ),
          ),

          // Content area
          Expanded(
            child: _buildContent(),
          ),

          // Instructions
          Container(
            padding: EdgeInsets.all(1),
            decoration: BoxDecoration(
              border: BoxBorder(
                top: BorderSide(color: Colors.gray),
              ),
            ),
            child: Text(
              'Use Tab to switch demos | Arrow keys to scroll | Page Up/Down for pages | Home/End for start/end',
              style: TextStyle(color: Colors.gray),
            ),
          ),
        ],
      ),
    );
  }

  Component _buildTab(String label, int index) {
    final isSelected = selectedTab == index;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2),
      decoration: isSelected
          ? BoxDecoration(
              color: Colors.blue,
            )
          : null,
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.brightWhite : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : null,
        ),
      ),
    );
  }

  Component _buildContent() {
    switch (selectedTab) {
      case 0:
        return _buildSingleChildScrollViewDemo();
      case 1:
        return _buildListViewDemo();
      case 2:
        return _buildListViewBuilderDemo();
      case 3:
        return _buildScrollbarDemo();
      default:
        return Container();
    }
  }

  Component _buildSingleChildScrollViewDemo() {
    return Padding(
      padding: EdgeInsets.all(1),
      child: Column(
        children: [
          Text('SingleChildScrollView Demo', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 1),
        Expanded(
          child: Row(
            children: [
              // Vertical scroll example
              Expanded(
                child: Column(
                  children: [
                    Text('Vertical Scroll:', style: TextStyle(color: Colors.green)),
                    SizedBox(height: 1),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: BoxBorder.all(color: Colors.green),
                        ),
                        child: SingleChildScrollView(
                          controller: scrollController1,
                          padding: EdgeInsets.all(1),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ScrollController Info:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(''),
                              for (int i = 0; i < 50; i++)
                                Text('Line $i: This is scrollable content that extends beyond the viewport'),
                              Text(''),
                              Text('--- END OF CONTENT ---', style: TextStyle(color: Colors.yellow)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 2),

              // Horizontal scroll example
              Expanded(
                child: Column(
                  children: [
                    Text('Horizontal Scroll:', style: TextStyle(color: Colors.blue)),
                    SizedBox(height: 1),
                    Container(
                      height: 5,
                      decoration: BoxDecoration(
                        border: BoxBorder.all(color: Colors.blue),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Text(
                                'This is a very long line of text that requires horizontal scrolling to read completely. '),
                            Text('It continues with more content here. '),
                            Text('And even more content to demonstrate horizontal scrolling capabilities.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Component _buildListViewDemo() {
    return Padding(
      padding: EdgeInsets.all(1),
      child: Column(
        children: [
          Text('ListView Demo (Static Children)', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 1),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: BoxBorder.all(color: Colors.magenta),
              ),
              child: ListView(
              controller: scrollController2,
              padding: EdgeInsets.all(1),
              children: [
                for (int i = 0; i < 30; i++)
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 1),
                    decoration: BoxDecoration(
                      border: BoxBorder(
                        bottom: BorderSide(color: Colors.gray),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text('[${i.toString().padLeft(2, '0')}]', style: TextStyle(color: Colors.cyan)),
                        SizedBox(width: 2),
                        Text('List item $i - Static content'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  Component _buildListViewBuilderDemo() {
    return Padding(
      padding: EdgeInsets.all(1),
      child: Column(
        children: [
          Text('ListView.builder Demo (Lazy Loading)', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 1),
        Expanded(
          child: Row(
            children: [
              // Standard builder
              Expanded(
                child: Column(
                  children: [
                    Text('Standard Builder:', style: TextStyle(color: Colors.yellow)),
                    SizedBox(height: 1),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: BoxBorder.all(color: Colors.yellow),
                        ),
                        child: ListView.builder(
                          itemCount: 1000,
                          itemBuilder: (context, index) {
                            return Container(
                              padding: EdgeInsets.all(1),
                              child: Text('Item #$index (of 1000) - Efficiently rendered on demand'),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 2),

              // Separated builder
              Expanded(
                child: Column(
                  children: [
                    Text('Separated Builder:', style: TextStyle(color: Colors.red)),
                    SizedBox(height: 1),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: BoxBorder.all(color: Colors.red),
                        ),
                        child: ListView.separated(
                          itemCount: 100,
                          itemBuilder: (context, index) {
                            return Container(
                              padding: EdgeInsets.symmetric(vertical: 1),
                              child: Text('Item $index'),
                            );
                          },
                          separatorBuilder: (context, index) {
                            return Container(
                              height: 1,
                              child: Center(
                                child: Text('─' * 20, style: TextStyle(color: Colors.gray)),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Component _buildListViewWithScrollbar() {
    final controller = ScrollController();
    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      thickness: 1,
      child: ListView.builder(
        controller: controller,
        itemCount: 200,
        itemExtent: 2,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: index % 2 == 0 ? Color.fromRGB(30, 30, 30) : Color.fromRGB(20, 20, 20),
            ),
            child: Text('Row $index'),
          );
        },
      ),
    );
  }

  Component _buildScrollbarDemo() {
    return Padding(
      padding: EdgeInsets.all(1),
      child: Column(
        children: [
          Text('Scrollbar Demo', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 1),
        Expanded(
          child: Row(
            children: [
              // SingleChildScrollView with scrollbar
              Expanded(
                child: Column(
                  children: [
                    Text('SingleChildScrollView + Scrollbar:', style: TextStyle(color: Colors.cyan)),
                    SizedBox(height: 1),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: BoxBorder.all(color: Colors.cyan),
                        ),
                        child: Scrollbar(
                          controller: scrollController3,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: scrollController3,
                            padding: EdgeInsets.all(1),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (int i = 0; i < 100; i++) Text('Line $i: Content with visible scrollbar indicator'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 2),

              // ListView with scrollbar
              Expanded(
                child: Column(
                  children: [
                    Text('ListView + Scrollbar:', style: TextStyle(color: Colors.green)),
                    SizedBox(height: 1),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: BoxBorder.all(color: Colors.green),
                        ),
                        child: _buildListViewWithScrollbar(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
}
