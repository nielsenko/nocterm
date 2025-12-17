import 'dart:async';
import 'dart:math';
import 'package:nocterm/nocterm.dart';

/// Demo simulating a test runner UI to test inline mode with scrollback.
/// This demonstrates how content taller than the terminal scrolls into
/// the scrollback buffer (frozen) while the bottom stays dynamic.
///
/// Run with: dart run example/test_runner_demo.dart
void main() async {
  await runApp(
    const TestRunnerDemo(),
    screenMode: ScreenMode.inline,
    inlineExitBehavior: InlineExitBehavior.preserve,
  );
}

/// Represents a single test result
class TestResult {
  final String file;
  final String name;
  final int durationMs;
  final bool passed;

  const TestResult({
    required this.file,
    required this.name,
    required this.durationMs,
    this.passed = true,
  });
}

/// All test definitions
const _testDefinitions = [
  ('test/auth/login_test.dart', 'User can login with valid credentials'),
  ('test/auth/login_test.dart', 'User cannot login with invalid password'),
  ('test/auth/logout_test.dart', 'User can logout successfully'),
  ('test/auth/register_test.dart', 'User can register new account'),
  ('test/auth/register_test.dart', 'Registration fails with existing email'),
  ('test/auth/password_reset_test.dart', 'Password reset email is sent'),
  ('test/auth/session_test.dart', 'Session expires after timeout'),
  ('test/api/users_test.dart', 'GET /users returns user list'),
  ('test/api/users_test.dart', 'POST /users creates new user'),
  ('test/api/users_test.dart', 'DELETE /users/:id removes user'),
  ('test/api/posts_test.dart', 'GET /posts returns all posts'),
  ('test/api/posts_test.dart', 'POST /posts creates new post'),
  ('test/api/posts_test.dart', 'PUT /posts/:id updates post'),
  ('test/api/comments_test.dart', 'GET /comments returns comments'),
  ('test/api/comments_test.dart', 'Comments are paginated correctly'),
  ('test/models/user_test.dart', 'User model serialization'),
  ('test/models/user_test.dart', 'User model validation'),
  ('test/models/post_test.dart', 'Post model serialization'),
  ('test/models/post_test.dart', 'Post timestamps are correct'),
  ('test/widgets/button_test.dart', 'Button renders correctly'),
  ('test/widgets/button_test.dart', 'Button handles tap events'),
  ('test/widgets/input_test.dart', 'Input accepts text'),
  ('test/widgets/input_test.dart', 'Input validates format'),
  ('test/widgets/card_test.dart', 'Card displays content'),
  ('test/widgets/list_test.dart', 'List renders items'),
  ('test/widgets/list_test.dart', 'List handles empty state'),
  ('test/utils/date_test.dart', 'Date formatting works'),
  ('test/utils/date_test.dart', 'Relative time calculation'),
  ('test/utils/string_test.dart', 'String truncation'),
  ('test/utils/string_test.dart', 'String sanitization'),
  ('test/utils/validator_test.dart', 'Email validation'),
  ('test/utils/validator_test.dart', 'Phone number validation'),
  ('test/integration/login_flow_test.dart', 'Complete login flow'),
  ('test/integration/signup_flow_test.dart', 'Complete signup flow'),
  ('test/integration/checkout_test.dart', 'Add items to cart'),
  ('test/integration/checkout_test.dart', 'Apply discount code'),
  ('test/integration/checkout_test.dart', 'Process payment'),
  ('test/integration/checkout_test.dart', 'Order confirmation email'),
  ('test/performance/load_test.dart', 'Handle 1000 concurrent users'),
  ('test/performance/query_test.dart', 'Database query optimization'),
];

class TestRunnerDemo extends StatefulComponent {
  const TestRunnerDemo({super.key});

  @override
  State<TestRunnerDemo> createState() => _TestRunnerDemoState();
}

class _TestRunnerDemoState extends State<TestRunnerDemo> {
  final List<TestResult> _completedTests = [];
  int _currentTestIndex = 0;
  Timer? _timer;
  final Random _random = Random();
  final Stopwatch _stopwatch = Stopwatch();
  int _spinnerFrame = 0;

  // Spinner animation frames
  static const _spinnerFrames = [
    '⠋',
    '⠙',
    '⠹',
    '⠸',
    '⠼',
    '⠴',
    '⠦',
    '⠧',
    '⠇',
    '⠏'
  ];

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _startTestRunner();
  }

  void _startTestRunner() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _spinnerFrame = (_spinnerFrame + 1) % _spinnerFrames.length;
      });

      // Complete a test every 200-400ms
      if (_random.nextInt(8) == 0 &&
          _currentTestIndex < _testDefinitions.length) {
        _completeCurrentTest();
      }
    });
  }

  void _completeCurrentTest() {
    if (_currentTestIndex >= _testDefinitions.length) return;

    final (file, name) = _testDefinitions[_currentTestIndex];
    final duration = 20 + _random.nextInt(300); // 20-320ms

    setState(() {
      _completedTests.add(TestResult(
        file: file,
        name: name,
        durationMs: duration,
        passed: true, // All tests pass in this demo
      ));
      _currentTestIndex++;
    });

    // Check if all tests are done
    if (_currentTestIndex >= _testDefinitions.length) {
      _timer?.cancel();
      _stopwatch.stop();
      // Wait a moment then exit
      Future.delayed(const Duration(seconds: 2), () {
        shutdownApp();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  String _formatElapsed() {
    final seconds = _stopwatch.elapsed.inMilliseconds / 1000;
    return '${seconds.toStringAsFixed(1)}s';
  }

  @override
  Component build(BuildContext context) {
    final isComplete = _currentTestIndex >= _testDefinitions.length;
    final passed = _completedTests.length;
    final failed = 0; // All pass in this demo

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Text(
          isComplete ? 'Tests completed!' : 'Running tests...',
          style: TextStyle(
            color: isComplete ? Colors.green : Colors.cyan,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 1),

        // Completed tests (static - can scroll into scrollback)
        for (final test in _completedTests)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '✓ ',
                style: TextStyle(color: Colors.green),
              ),
              Text(
                test.file,
                style: TextStyle(color: Colors.grey),
              ),
              Text(' - '),
              Text(test.name),
              Text(
                ' (${test.durationMs}ms)',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),

        // Currently running test (dynamic)
        if (!isComplete && _currentTestIndex < _testDefinitions.length)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_spinnerFrames[_spinnerFrame]} ',
                style: TextStyle(color: Colors.yellow),
              ),
              Text(
                _testDefinitions[_currentTestIndex].$1,
                style: TextStyle(color: Colors.grey),
              ),
              Text(' - '),
              Text(_testDefinitions[_currentTestIndex].$2),
              Text(
                ' (running)',
                style: TextStyle(color: Colors.yellow),
              ),
            ],
          ),

        // Separator and summary
        const SizedBox(height: 1),
        Text(
          '─' * 50,
          style: TextStyle(color: Colors.grey),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$passed passed',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(', '),
            Text(
              '$failed failed',
              style: TextStyle(
                color: failed > 0 ? Colors.red : Colors.grey,
                fontWeight: failed > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Text(' | '),
            Text(
              '${_formatElapsed()} elapsed',
              style: TextStyle(color: Colors.cyan),
            ),
            if (isComplete) ...[
              Text(' '),
              Text(
                '✓ All tests passed!',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
