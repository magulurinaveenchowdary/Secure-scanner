import 'package:flutter/material.dart';

class RestartWidget extends StatefulWidget {
  final Widget child;
  const RestartWidget({Key? key, required this.child}) : super(key: key);

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<RestartWidgetState>()?.restartApp();
  }

  @override
  RestartWidgetState createState() => RestartWidgetState();
}

class RestartWidgetState extends State<RestartWidget> {
  Key _key = UniqueKey();

  void restartApp() {
    setState(() {
      _key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: widget.child,
    );
  }
}
