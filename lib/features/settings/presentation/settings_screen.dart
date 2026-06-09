import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإعدادات'),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(
              leading: const Icon(Icons.business, color: Colors.blueGrey),
              title: const Text('بيانات الشركة'),
              subtitle: const Text('الاسم، الشعار، بيانات البنك والاتصال'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () {
                context.go('/settings/company-setup');
              },
            ),
            const Divider(),
          ],
        ),
      ),
    );
  }
}
