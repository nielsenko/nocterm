import '../framework/framework.dart';
import '../components/basic.dart';
import '../components/stack.dart' show Alignment;
import '../style.dart';
import 'route_settings.dart';

/// Base class for routes in the navigation system
abstract class Route<T> {
  /// The component to display for this route
  final Component component;

  /// The settings for this route (name, arguments)
  final RouteSettings settings;

  /// Whether this route is a modal overlay
  final bool isModal;

  const Route({
    required this.component,
    required this.settings,
    this.isModal = false,
  });

  /// Check if this route can be popped.
  /// Override to prevent popping in certain conditions.
  bool canPop() => true;
}

/// A standard page route
class PageRoute<T> extends Route<T> {
  const PageRoute({
    required super.component,
    required super.settings,
  }) : super(isModal: false);
}

/// A modal overlay route (like a dialog)
class ModalRoute<T> extends Route<T> {
  /// Whether tapping outside the modal dismisses it
  final bool barrierDismissible;

  /// Decoration for the modal container
  final BoxDecoration? decoration;

  /// Alignment of the modal on screen
  final Alignment alignment;

  /// Width constraint for the modal
  final double? width;

  /// Height constraint for the modal
  final double? height;

  const ModalRoute({
    required super.component,
    required super.settings,
    this.barrierDismissible = true,
    this.decoration,
    this.alignment = Alignment.center,
    this.width,
    this.height,
  }) : super(isModal: true);
}

/// Factory for creating routes from settings
typedef RouteFactory = Route<dynamic>? Function(RouteSettings settings);
