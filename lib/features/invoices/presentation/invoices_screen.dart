import 'package:flutter/material.dart';

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفواتير'),
      ),
      body: const Center(
        child: Text(
          'الفواتير',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
