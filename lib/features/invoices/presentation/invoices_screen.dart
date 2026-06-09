import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fawatir/app/theme.dart';

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الفواتير'),
        ),
        body: const Center(
          child: Text(
            'لا توجد فواتير بعد',
            style: TextStyle(fontSize: 18, color: AppColors.muted),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          onPressed: () {
            context.go('/invoices/new');
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
