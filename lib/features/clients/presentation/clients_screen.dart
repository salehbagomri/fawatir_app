import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/features/clients/application/client_providers.dart';
import 'package:fawatir/core/money.dart';
import 'package:fawatir/data/db/database.dart';
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextFormField(
                initialValue: search,
                onChanged: (val) {
                  ref.read(clientSearchProvider.notifier).setQuery(val);
                },
                decoration: InputDecoration(
                  hintText: 'البحث عن عميل بالاسم أو الهاتف...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            ref.read(clientSearchProvider.notifier).setQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.line.withValues(alpha: 0.6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.line.withValues(alpha: 0.6)),
                  ),
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

                  return ListView.builder(
                    itemCount: clients.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemBuilder: (context, index) {
                      return _ClientCard(client: clients[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 2,
          icon: const Icon(Icons.person_add_rounded),
          label: const Text(
            'عميل جديد',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            context.go('/clients/add');
          },
        ),
      ),
    );
  }
}

class _ClientCard extends ConsumerWidget {
  final Client client;
  const _ClientCard({required this.client});

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF1F3A5F),
      const Color(0xFF0D9488),
      const Color(0xFFD97706),
      const Color(0xFF7C3AED),
      const Color(0xFF2563EB),
      const Color(0xFF059669),
    ];
    final index = name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0;
    return colors[index];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(clientBalanceProvider(client.id));
    final avatarColor = _getAvatarColor(client.name);
    final initialLetter = client.name.trim().isNotEmpty
        ? client.name.trim().characters.first
        : '?';

    final subtitleParts = <String>[];
    if (client.contactPerson != null && client.contactPerson!.isNotEmpty) {
      subtitleParts.add(client.contactPerson!);
    }
    if (client.phone != null && client.phone!.isNotEmpty) {
      subtitleParts.add(client.phone!);
    }
    final subtitle = subtitleParts.isEmpty ? 'لا توجد تفاصيل اتصال' : subtitleParts.join(' • ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.line.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          context.go('/clients/${client.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: avatarColor,
                child: Text(
                  initialLetter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            client.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.dark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Balance & Currency
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  balanceAsync.when(
                    data: (bal) {
                      final isDebt = bal > 0;
                      final isZero = bal == 0;
                      final color = isDebt
                          ? Colors.red.shade700
                          : (isZero ? Colors.green.shade700 : Colors.teal.shade700);

                      return Text(
                        formatMoney(bal.abs(), client.accountCurrency),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      );
                    },
                    loading: () => const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                    error: (_, stack) => Text(
                      client.accountCurrency,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  balanceAsync.maybeWhen(
                    data: (bal) {
                      final label = bal > 0
                          ? 'مستحق'
                          : (bal == 0 ? 'مسدد' : 'رصيد دائن');
                      final labelColor = bal > 0
                          ? Colors.red.shade600
                          : Colors.green.shade600;

                      return Text(
                        label,
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                    orElse: () => Text(
                      client.accountCurrency,
                      style: const TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_left, color: AppColors.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
