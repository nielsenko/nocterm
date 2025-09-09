import 'dart:async';
import '../framework/framework.dart';
import '../components/basic.dart';
import '../components/render_stack.dart' show Stack;
import '../components/stack.dart' show Positioned, Alignment;
import '../components/keyboard_listener.dart';
import '../components/block_focus.dart';
import '../keyboard/logical_key.dart';
import '../style.dart';
import 'route.dart';
import 'route_settings.dart';
import 'pop_behavior.dart';
import 'navigator_observer.dart';

/// A widget that manages a stack of routes
class TuiNavigator extends StatefulComponent {
  /// The initial home route
  final Component? home;

  /// Map of named routes
  final Map<String, Component Function(BuildContext)>? routes;

  /// Initial route path for deep linking
  final String? initialRoute;

  /// Factory for generating routes
  final RouteFactory? onGenerateRoute;

  /// Factory for unknown routes
  final RouteFactory? onUnknownRoute;

  /// Configuration for pop behavior
  final PopBehavior popBehavior;

  /// Observers for navigation events
  final List<NavigatorObserver> observers;

  const TuiNavigator({
    super.key,
    this.home,
    this.routes,
    this.initialRoute,
    this.onGenerateRoute,
    this.onUnknownRoute,
    this.popBehavior = const PopBehavior(),
    this.observers = const [],
  }) : assert(home != null || routes != null || onGenerateRoute != null,
            'Either home, routes, or onGenerateRoute must be provided');

  @override
  State<TuiNavigator> createState() => NavigatorState();

  /// Get the navigator state from the context
  static NavigatorState? maybeOf(BuildContext context) {
    final state = context.findAncestorStateOfType<NavigatorState>();
    return state;
  }

  /// Get the navigator state from the context (throws if not found)
  static NavigatorState of(BuildContext context) {
    final NavigatorState? navigator = maybeOf(context);
    assert(navigator != null, 'No TuiNavigator found in context');
    return navigator!;
  }
}

/// State for the TuiNavigator
class NavigatorState extends State<TuiNavigator> {
  final List<_RouteEntry> _routeStack = [];
  final StreamController<void> _navigationStream = StreamController.broadcast();
  final Map<Route, Completer<dynamic>> _routeCompleters = {};

  @override
  void initState() {
    super.initState();
    _initializeRoutes();
  }

  @override
  void dispose() {
    _navigationStream.close();
    super.dispose();
  }

  void _initializeRoutes() {
    if (component.initialRoute != null) {
      _buildInitialRouteStack(component.initialRoute!);
    } else if (component.home != null) {
      final route = PageRoute(
        component: component.home!,
        settings: const RouteSettings(name: '/'),
      );
      _routeStack.add(_RouteEntry(route));
    } else if (component.routes != null && component.routes!.containsKey('/')) {
      final route = PageRoute(
        component: component.routes!['/']!(context),
        settings: const RouteSettings(name: '/'),
      );
      _routeStack.add(_RouteEntry(route));
    }

    // Notify observers
    for (final entry in _routeStack) {
      for (final observer in component.observers) {
        observer.didPush(entry.route, null);
      }
    }
  }

  void _buildInitialRouteStack(String initialRoute) {
    final segments = initialRoute.split('/').where((s) => s.isNotEmpty).toList();

    // Always start with home route if available
    if (component.home != null || (component.routes?.containsKey('/') ?? false)) {
      final homeRoute = PageRoute(
        component: component.home ?? component.routes!['/']!(context),
        settings: const RouteSettings(name: '/'),
      );
      _routeStack.add(_RouteEntry(homeRoute));
    }

    // Build up the route stack
    String currentPath = '';
    for (final segment in segments) {
      currentPath += '/$segment';
      final route = _createRoute(RouteSettings(name: currentPath));
      if (route != null) {
        _routeStack.add(_RouteEntry(route));
      }
    }
  }

  Route? _createRoute(RouteSettings settings) {
    // Try named routes first
    if (settings.name != null && component.routes != null) {
      final builder = component.routes![settings.name];
      if (builder != null) {
        return PageRoute(
          component: builder(context),
          settings: settings,
        );
      }
    }

    // Try onGenerateRoute
    if (component.onGenerateRoute != null) {
      final route = component.onGenerateRoute!(settings);
      if (route != null) return route;
    }

    // Fall back to onUnknownRoute
    if (component.onUnknownRoute != null) {
      return component.onUnknownRoute!(settings);
    }

    return null;
  }

  /// Push a new route onto the stack
  Future<T?> push<T>(Route<T> route) {
    setState(() {
      _routeStack.add(_RouteEntry(route));
    });

    // Notify observers
    for (final observer in component.observers) {
      observer.didPush(route, _routeStack.length > 1 ? _routeStack[_routeStack.length - 2].route : null);
    }

    final completer = Completer<T?>();
    _routeCompleters[route] = completer;
    return completer.future;
  }

  /// Push a component directly onto the navigation stack.
  ///
  /// Returns a Future that completes with the result when the route is popped.
  Future<T?> pushComponent<T>(Component component, {String? name}) {
    final route = PageRoute<T>(
      component: component,
      settings: RouteSettings(name: name),
    );
    return push(route);
  }

  /// Push a named route
  Future<T?> pushNamed<T>(String name, {Object? arguments}) {
    final settings = RouteSettings(name: name, arguments: arguments);
    final route = _createRoute(settings);

    if (route == null) {
      throw FlutterError('Could not find a route named "$name"');
    }

    return push(route as Route<T>);
  }

  /// Replace the current route with a new one.
  ///
  /// The [result] parameter will be passed to the previous route's future.
  /// Returns a Future that completes with the result when the new route is popped.
  Future<T?> pushReplacement<T, TO>(Route<T> route, {TO? result}) {
    if (_routeStack.isNotEmpty) {
      final oldRoute = _routeStack.last.route;

      setState(() {
        _routeStack.removeLast();
        _routeStack.add(_RouteEntry(route));
      });

      // Notify observers
      for (final observer in component.observers) {
        observer.didReplace(newRoute: route, oldRoute: oldRoute);
      }

      // Complete the old route's future
      if (_routeCompleters.containsKey(oldRoute)) {
        _routeCompleters[oldRoute]!.complete(result);
        _routeCompleters.remove(oldRoute);
      }
    } else {
      return push(route);
    }

    final completer = Completer<T?>();
    _routeCompleters[route] = completer;
    return completer.future;
  }

  /// Replace with a named route
  Future<T?> pushReplacementNamed<T, TO>(String name, {Object? arguments, TO? result}) {
    final settings = RouteSettings(name: name, arguments: arguments);
    final route = _createRoute(settings);

    if (route == null) {
      throw FlutterError('Could not find a route named "$name"');
    }

    return pushReplacement(route as Route<T>, result: result);
  }

  /// Pop the current route off the navigation stack.
  ///
  /// The [result] will be passed to the route's future.
  /// Does nothing if there's only one route in the stack.
  void pop<T>([T? result]) {
    if (!canPop()) return;

    final route = _routeStack.last.route;

    setState(() {
      _routeStack.removeLast();
    });

    // Notify observers
    for (final observer in component.observers) {
      observer.didPop(route, _routeStack.isNotEmpty ? _routeStack.last.route : null);
    }

    // Complete the route's future
    if (_routeCompleters.containsKey(route)) {
      _routeCompleters[route]!.complete(result);
      _routeCompleters.remove(route);
    }
  }

  /// Pop routes until the predicate returns true.
  ///
  /// The [predicate] is called with each route starting from the top of the stack.
  /// Stops when predicate returns true or the stack has only one route.
  void popUntil(bool Function(Route) predicate) {
    while (_routeStack.isNotEmpty && !predicate(_routeStack.last.route)) {
      pop();
    }
  }

  /// Push a new route and remove all routes until predicate returns true.
  ///
  /// This is useful for resetting the navigation stack to a known state.
  Future<T?> pushAndRemoveUntil<T>(Route<T> route, bool Function(Route) predicate) {
    // Remove routes until predicate is true
    while (_routeStack.isNotEmpty && !predicate(_routeStack.last.route)) {
      final oldRoute = _routeStack.removeLast().route;

      // Notify observers
      for (final observer in component.observers) {
        observer.didRemove(oldRoute, null);
      }

      // Complete the old route's future
      if (_routeCompleters.containsKey(oldRoute)) {
        _routeCompleters[oldRoute]!.complete(null);
        _routeCompleters.remove(oldRoute);
      }
    }

    return push(route);
  }

  /// Check if the current route can be popped.
  ///
  /// Returns false if there's only one route or if the PopBehavior prevents it.
  bool canPop() {
    if (_routeStack.length <= 1) return false;

    final currentRoute = _routeStack.last.route;

    // Check route's own canPop
    if (!currentRoute.canPop()) return false;

    // Check PopBehavior's canPop
    if (component.popBehavior.canPop != null) {
      return component.popBehavior.canPop!(currentRoute);
    }

    return true;
  }

  /// Show a modal dialog
  Future<T?> showDialog<T>({
    required Component Function(BuildContext) builder,
    bool barrierDismissible = true,
    BoxDecoration? decoration,
    Alignment alignment = Alignment.center,
    double? width,
    double? height,
  }) {
    final route = ModalRoute<T>(
      component: builder(context),
      settings: const RouteSettings(name: '<dialog>'),
      barrierDismissible: barrierDismissible,
      decoration: decoration ??
          BoxDecoration(
            border: BoxBorder.all(style: BoxBorderStyle.double),
            color: const Color.fromRGB(0, 0, 0),
          ),
      alignment: alignment,
      width: width,
      height: height,
    );

    return push(route);
  }

  bool _handleKeyPress(LogicalKey key) {
    if (component.popBehavior.shouldPop(key)) {
      // Check if current route is modal with barrierDismissible
      final currentRoute = _routeStack.last.route;
      if (currentRoute is ModalRoute && !currentRoute.barrierDismissible) {
        return false; // Don't pop if barrier is not dismissible
      }

      // Handle async pop confirmation
      if (component.popBehavior.onPopInvoked != null) {
        component.popBehavior.onPopInvoked!(currentRoute).then((shouldPop) {
          if (shouldPop && canPop()) {
            pop();
          }
        });
        return true; // Event was handled (async)
      } else if (canPop()) {
        pop();
        return true; // Event was handled
      }
    }

    return false; // Event was not handled
  }

  @override
  Component build(BuildContext context) {
    if (_routeStack.isEmpty) {
      return Container(
        child: const Center(
          child: Text('No routes'),
        ),
      );
    }

    // Find all modal routes at the top of the stack
    int firstModalIndex = _routeStack.length;
    for (int i = _routeStack.length - 1; i >= 0; i--) {
      if (_routeStack[i].route.isModal) {
        firstModalIndex = i;
      } else {
        break;
      }
    }

    // Build the component tree
    if (firstModalIndex < _routeStack.length) {
      // We have modals to render
      final List<Component> stackChildren = [];

      // Render the last non-modal route as background (fill the entire screen)
      // Wrap it in BlockFocus to prevent keyboard events from reaching it
      if (firstModalIndex > 0) {
        stackChildren.add(
          Positioned.fill(
            child: BlockFocus(
              blocking: true,
              child: _routeStack[firstModalIndex - 1].route.component,
            ),
          ),
        );
      } else {
        // If the first route is a modal, we need some background
        stackChildren.add(
          Positioned.fill(
            child: Container(),
          ),
        );
      }

      // Render each modal
      for (int i = firstModalIndex; i < _routeStack.length; i++) {
        final route = _routeStack[i].route;
        if (route is ModalRoute) {
          // Add modal content
          Component modalContent = route.component;

          // Apply decoration if provided
          if (route.decoration != null) {
            modalContent = DecoratedBox(
              decoration: route.decoration!,
              child: modalContent,
            );
          }

          // Apply size constraints if provided
          if (route.width != null || route.height != null) {
            modalContent = SizedBox(
              width: route.width,
              height: route.height,
              child: modalContent,
            );
          }

          // Apply alignment - always use Positioned.fill for proper Stack positioning
          stackChildren.add(
            Positioned.fill(
              child: Align(
                alignment: route.alignment,
                child: modalContent,
              ),
            ),
          );
        }
      }

      // Wrap the stack in a KeyboardListener that doesn't block events
      return KeyboardListener(
        onKeyEvent: _handleKeyPress,
        autofocus: true,
        child: Stack(children: stackChildren),
      );
    }

    // No modals, just render the current route
    return KeyboardListener(
      onKeyEvent: _handleKeyPress,
      autofocus: true,
      child: _routeStack.last.route.component,
    );
  }
}

/// Internal class to track route entries
class _RouteEntry {
  final Route route;

  _RouteEntry(this.route);
}
