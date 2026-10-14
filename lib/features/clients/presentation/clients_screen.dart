import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/features/clients/application/client_providers.dart';
import 'package:fawatir/shared/widgets/empty_state.dart';

class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(clientSearchProvider);
    final clientsAsync = ref.watch(clientsStreamProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('العملاء'),
        ),
        body: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextFormField(
                initialValue: search,
                onChanged: (val) {
                  ref.read(clientSearchProvider.notifier).setQuery(val);
                },
                decoration: InputDecoration(
                  labelText: 'البحث عن عميل...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            ref.read(clientSearchProvider.notifier).setQuery('');
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),

            // Clients List
            Expanded(
              child: clientsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('خطأ في التحميل: $err')),
                data: (clients) {
                  if (clients.isEmpty) {
                    if (search.trim().isNotEmpty) {
                      return EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'لا توجد نتائج مطابقة',
                        subtitle: 'لم نتمكن من العثور على عميل يطابق "$search"',
                        actionLabel: 'مسح البحث',
                        actionIcon: Icons.clear,
                        onAction: () {
                          ref.read(clientSearchProvider.notifier).setQuery('');
                        },
                      );
                    }
                    return EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'لا يوجد عملاء بعد',
                      subtitle: 'ابدأ بإضافة أول عميل لإصدار الفواتير ومتابعة الحسابات والتحصيلات',
                      actionLabel: 'إضافة عميل جديد',
                      actionIcon: Icons.person_add_outlined,
                      onAction: () {
                        context.go('/clients/add');
                      },
                    );
                  }

                  return ListView.separated(
                    itemCount: clients.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final client = clients[index];
                      final subtitleParts = <String>[];
                      if (client.contactPerson != null && client.contactPerson!.isNotEmpty) {
                        subtitleParts.add(client.contactPerson!);
                      }
                      if (client.phone != null && client.phone!.isNotEmpty) {
                        subtitleParts.add(client.phone!);
                      }
                      final subtitle = subtitleParts.isEmpty ? 'لا توجد تفاصيل اتصال' : subtitleParts.join(' • ');

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        title: Row(
                          children: [
                            Text(
                              client.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            if (!client.isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Text(
                                  'غير نشط',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          subtitle,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              client.accountCurrency,
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_left, color: AppColors.muted),
                          ],
                        ),
                        onTap: () {
                          // Open client detail screen
                          context.go('/clients/${client.id}');
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          onPressed: () {
            context.go('/clients/add');
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
