import 'package:flutter/material.dart';

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('العملاء'),
      ),
      body: const Center(
        child: Text(
          'العملاء',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
