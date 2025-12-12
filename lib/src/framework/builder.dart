part of 'framework.dart';

class Builder extends StatelessComponent {
  const Builder({super.key, required this.builder});

  final Component Function(BuildContext context) builder;

  @override
  Component build(BuildContext context) {
    return builder(context);
  }
}
