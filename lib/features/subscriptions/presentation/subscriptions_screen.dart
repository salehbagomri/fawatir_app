import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/core/money.dart';
import 'package:fawatir/features/clients/application/client_providers.dart';
import 'package:fawatir/features/subscriptions/application/subscription_providers.dart';
import 'package:fawatir/features/subscriptions/data/subscription_repository.dart';

class SubscriptionsScreen extends ConsumerWidget {
  final int clientId;
  const SubscriptionsScreen({super.key, required this.clientId});

  String _formatDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(clientByIdProvider(clientId));
    final subsAsync = ref.watch(clientSubscriptionsProvider(clientId));

    final clientName = clientAsync.when(
      data: (c) => c?.name ?? 'العميل',
      loading: () => '...',
      error: (e, s) => 'العميل',
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('اشتراكات $clientName'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Go back to client details
              context.go('/clients/$clientId');
            },
          ),
        ),
        body: subsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('خطأ في تحميل الاشتراكات: $err')),
          data: (subscriptions) {
            if (subscriptions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.autorenew_outlined,
                      size: 64,
                      color: AppColors.muted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'لا توجد اشتراكات بعد لهذا العميل',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: subscriptions.length,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemBuilder: (context, index) {
                final sub = subscriptions[index];
                final priceStr = formatMoney(sub.unitPriceMinor, sub.currency);
                final billingDayStr = 'يوم الفوترة: ${sub.billingDayOfMonth} في الشهر';
                final periodStr =
                    'يبدأ من: ${_formatDate(sub.startDate)}${sub.endDate != null ? ' إلى: ${_formatDate(sub.endDate!)}' : ''}';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.line.withValues(alpha: 0.5)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            sub.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        _buildStatusBadge(sub.isActive),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: AppColors.muted),
                            const SizedBox(width: 6),
                            Text(billingDayStr, style: const TextStyle(fontSize: 12, color: AppColors.dark)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.date_range, size: 14, color: AppColors.muted),
                            const SizedBox(width: 6),
                            Text(periodStr, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          priceStr,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: sub.isActive ? AppColors.accent : AppColors.muted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: sub.isActive,
                          activeThumbColor: AppColors.accent,
                          onChanged: (val) async {
                            try {
                              await ref.read(subscriptionRepositoryProvider).setSubscriptionActive(sub.id, val);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(val ? 'تم تفعيل الاشتراك بنجاح' : 'تم إيقاف الاشتراك بنجاح'),
                                    backgroundColor: val ? Colors.green.shade700 : Colors.grey.shade700,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('خطأ أثناء تعديل حالة الاشتراك: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      context.go('/clients/$clientId/subscriptions/edit/${sub.id}');
                    },
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          onPressed: () {
            context.go('/clients/$clientId/subscriptions/add');
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    final text = isActive ? 'نشط' : 'متوقف';
    final bgColor = isActive ? Colors.green.shade50 : Colors.grey.shade100;
    final textColor = isActive ? Colors.green.shade700 : Colors.grey.shade700;
    final borderColor = isActive ? Colors.green.shade200 : Colors.grey.shade300;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
