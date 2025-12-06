import 'package:nocterm/src/framework/framework.dart';

/// Signature for a function that builds a component given a [BuildContext].
typedef WidgetBuilder = Component Function(BuildContext context);

/// A stateless utility component whose [build] method uses its
/// [builder] callback to create the component's child.
///
/// This is useful when you want to create a component inline without
/// defining a separate class.
///
/// Example:
/// ```dart
/// Builder(
///   builder: (context) => Text('Hello World'),
/// )
/// ```
class Builder extends StatelessComponent {
  /// Creates a widget that delegates its building to a callback.
  const Builder({super.key, required this.builder});

  /// Called to obtain the child component.
  ///
  /// This function is called whenever this component is included in its
  /// parent's build and the old component (if any) that it synchronizes
  /// with has a distinct object identity.
  final WidgetBuilder builder;

  @override
  Component build(BuildContext context) => builder(context);
}
