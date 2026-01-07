import 'package:flutter/material.dart';

class ScanResultPreview extends StatelessWidget {
  final String content;
  const ScanResultPreview({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Result')),
      body: Center(child: Text(content)),
    );
  }
}
