export 'nocterm_test.dart';
export 'src/app.dart';
export 'src/backend/socket_backend_export.dart';
// Platform-specific backends use conditional exports
export 'src/backend/stdio_backend_export.dart';
export 'src/backend/terminal.dart';
export 'src/backend/terminal_backend.dart';
export 'src/backend/web_backend_export.dart';
export 'src/binding/run_app.dart' show runApp;
export 'src/binding/scheduler_binding.dart';
export 'src/binding/scheduler_phase.dart';
export 'src/binding/terminal_binding.dart';
export 'src/buffer.dart';
export 'src/components/auto_scroll_controller.dart';
export 'src/components/basic.dart';
export 'src/components/block_focus.dart';
export 'src/components/divider.dart';
export 'src/components/focus_scope.dart';
export 'src/components/focusable.dart';
export 'src/components/gesture_detector.dart';
export 'src/components/list_view.dart';
export 'src/components/markdown_text.dart';
export 'src/components/builder.dart';
// Mouse and Gesture Support
export 'src/components/mouse_region.dart';
export 'src/components/performance_overlay.dart';
export 'src/components/progress_bar.dart';
export 'src/components/render_stack.dart' show Stack;
export 'src/components/scroll_controller.dart';
export 'src/components/scrollbar.dart';
export 'src/components/single_child_scroll_view.dart';
export 'src/components/spacer.dart';
export 'src/components/stack.dart';
export 'src/components/terminal_xterm.dart';
export 'src/components/text_field.dart';
// Performance and Debugging
export 'src/foundation/performance.dart';
export 'src/frame.dart';
export 'src/framework/axis.dart';
export 'src/framework/framework.dart';
export 'src/framework/listenable.dart';
export 'src/gestures/events.dart';
export 'src/gestures/hit_test.dart';
export 'src/gestures/long_press.dart';
export 'src/gestures/recognizer.dart';
export 'src/gestures/tap.dart';
// Navigation
export 'src/navigation/navigator.dart';
export 'src/navigation/navigator_observer.dart';
export 'src/navigation/overlay.dart';
export 'src/navigation/pop_behavior.dart';
export 'src/navigation/route.dart';
export 'src/navigation/route_settings.dart';
export 'src/process/pty_controller.dart';
export 'src/rectangle.dart';
export 'src/rendering/debug.dart';
export 'src/shutdown.dart' show shutdownApp;
export 'src/size.dart';
export 'src/style.dart';
export 'src/test/matchers.dart';
export 'src/test/nocterm_test_binding.dart';
export 'src/test/nocterm_tester.dart';
export 'src/test/terminal_state.dart';
// Utilities
export 'src/utils/clipboard.dart';
export 'src/utils/log_server.dart';
export 'src/utils/logger.dart';
export 'src/utils/nocterm_paths.dart';
// Widgets
export 'src/widgets/nocterm_app.dart';

// Builder components
export 'src/components/builder.dart';
export 'src/components/layout_builder.dart';
