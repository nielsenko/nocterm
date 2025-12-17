import 'dart:async';
import 'package:nocterm/nocterm.dart';

/// Demo showing inline screen mode - renders without alternate screen.
/// Output stays in terminal history after the app exits.
///
/// Run with: dart run example/inline_demo.dart
void main() async {
  await runApp(
    const InlineDemo(),
    screenMode: ScreenMode.inline,
    inlineExitBehavior: InlineExitBehavior.preserve,
  );
}

class InlineDemo extends StatefulComponent {
  const InlineDemo({super.key});

  @override
  State<InlineDemo> createState() => _InlineDemoState();
}

class _InlineDemoState extends State<InlineDemo> {
  int progress = 0;
  Timer? _timer;
  final List<String> steps = [
    'Analyzing project structure...',
    'Compiling main.dart...',
    'Compiling app.dart...',
    'Compiling utils.dart...',
    'Linking dependencies...',
    'Optimizing output...',
    'Generating assets...',
    'Finalizing build...',
    'Writing output...',
    'Build complete!',
  ];

  @override
  void initState() {
    super.initState();
    _startProgress();
  }

  void _startProgress() {
    _timer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (progress < 100) {
        setState(() {
          progress += 10;
        });
      } else {
        timer.cancel();
        // Wait a moment then exit
        Future.delayed(const Duration(milliseconds: 500), () {
          shutdownApp();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _buildProgressBar(int value, int width) {
    final filled = (value / 100 * width).round();
    final empty = width - filled;
    return '${'█' * filled}${'░' * empty}';
  }

  @override
  Component build(BuildContext context) {
    final stepIndex = (progress / 10).floor().clamp(0, steps.length - 1);
    final currentStep = steps[stepIndex];
    final isComplete = progress >= 100;

    return SizedBox(
      height: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isComplete ? 'Build successful!' : 'Building project...',
            style: TextStyle(
              color: isComplete ? Colors.green : Colors.cyan,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 1),
          Row(
            children: [
              Text('['),
              Text(
                _buildProgressBar(progress, 30),
                style: TextStyle(
                  color: isComplete ? Colors.green : Colors.blue,
                ),
              ),
              Text('] '),
              Text(
                '$progress%',
                style: TextStyle(
                  color: Colors.yellow,
                ),
              ),
              Text(' - '),
              Text(
                currentStep,
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
