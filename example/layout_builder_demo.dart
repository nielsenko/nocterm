import 'package:nocterm/nocterm.dart';

void main() {
  runApp(const LayoutBuilderDemo());
}

class LayoutBuilderDemo extends StatelessComponent {
  const LayoutBuilderDemo({super.key});

  @override
  Component build(BuildContext context) {
    // Wrap everything in a LayoutBuilder to get the actual terminal size
    return LayoutBuilder(
      builder: (context, terminalConstraints) {
        final terminalWidth = terminalConstraints.maxWidth.toInt();
        final terminalHeight = terminalConstraints.maxHeight.toInt();

        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              decoration: const BoxDecoration(
                border: BoxBorder(bottom: BorderSide(color: Colors.cyan)),
              ),
              child: const Center(
                child: Text(
                  'LayoutBuilder Demo - Responsive Layouts',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: Colors.cyan),
                ),
              ),
            ),

            // Main content with responsive layout
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth.toInt();
                    final height = constraints.maxHeight.toInt();

                    // Show different layouts based on available width
                    if (width >= 80) {
                      return _buildWideLayout(width, height);
                    } else if (width >= 50) {
                      return _buildMediumLayout(width, height);
                    } else {
                      return _buildNarrowLayout(width, height);
                    }
                  },
                ),
              ),
            ),

            // Footer showing current terminal dimensions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: const BoxDecoration(
                border: BoxBorder(top: BorderSide(color: Colors.grey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Terminal: ${terminalWidth}x$terminalHeight',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const Text(
                    'Resize terminal to see responsive behavior',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Component _buildWideLayout(int width, int height) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(1),
          child: Text(
            'Wide Layout (>= 80 cols) - Content area: ${width}x$height',
            style:
                const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              // Left panel
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 1),
                  decoration: BoxDecoration(
                    border: BoxBorder.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(1),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(1),
                        decoration: const BoxDecoration(
                          border:
                              BoxBorder(bottom: BorderSide(color: Colors.blue)),
                        ),
                        child: const Center(child: Text('Left Panel')),
                      ),
                      Expanded(
                        child: Center(
                          child: Text('Navigation or sidebar content'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Center panel
              Expanded(
                flex: 2,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    border: BoxBorder.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(1),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(1),
                        decoration: const BoxDecoration(
                          border: BoxBorder(
                              bottom: BorderSide(color: Colors.green)),
                        ),
                        child: const Center(child: Text('Main Content')),
                      ),
                      Expanded(
                        child: Center(
                          child: Text('Primary content area'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Right panel
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: 1),
                  decoration: BoxDecoration(
                    border: BoxBorder.all(color: Colors.magenta),
                    borderRadius: BorderRadius.circular(1),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(1),
                        decoration: const BoxDecoration(
                          border: BoxBorder(
                              bottom: BorderSide(color: Colors.magenta)),
                        ),
                        child: const Center(child: Text('Right Panel')),
                      ),
                      Expanded(
                        child: Center(
                          child: Text('Details or info'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Component _buildMediumLayout(int width, int height) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(1),
          child: Text(
            'Medium Layout (50-79 cols) - Content area: ${width}x$height',
            style: const TextStyle(
                color: Colors.yellow, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              // Left panel
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 1),
                  decoration: BoxDecoration(
                    border: BoxBorder.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(1),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(1),
                        decoration: const BoxDecoration(
                          border:
                              BoxBorder(bottom: BorderSide(color: Colors.blue)),
                        ),
                        child: const Center(child: Text('Sidebar')),
                      ),
                      Expanded(
                        child: Center(child: Text('Nav')),
                      ),
                    ],
                  ),
                ),
              ),
              // Main panel (takes more space)
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    border: BoxBorder.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(1),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(1),
                        decoration: const BoxDecoration(
                          border: BoxBorder(
                              bottom: BorderSide(color: Colors.green)),
                        ),
                        child: const Center(child: Text('Content')),
                      ),
                      Expanded(
                        child: Center(
                          child: Text('Two-column layout'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Component _buildNarrowLayout(int width, int height) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(1),
          child: Text(
            'Narrow Layout (< 50 cols) - ${width}x$height',
            style:
                const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              border: BoxBorder.all(color: Colors.cyan),
              borderRadius: BorderRadius.circular(1),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(1),
                  decoration: const BoxDecoration(
                    border: BoxBorder(bottom: BorderSide(color: Colors.cyan)),
                  ),
                  child: const Center(child: Text('Single Column')),
                ),
                Expanded(
                  child: Center(
                    child: Text('Stacked layout'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
