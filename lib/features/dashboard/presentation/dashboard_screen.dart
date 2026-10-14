import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/core/money.dart';
import 'package:go_router/go_router.dart';
import 'package:fawatir/data/db/tables.dart';
import 'package:fawatir/features/company/application/company_providers.dart';
import 'package:fawatir/features/invoices/data/invoice_repository.dart';
import 'package:fawatir/features/invoices/application/invoice_providers.dart';
import 'package:fawatir/shared/widgets/confirm_dialog.dart';
import 'package:fawatir/shared/widgets/app_snackbar.dart';
import 'package:fawatir/features/payments/data/payment_repository.dart';
import '../data/dashboard_repository.dart';
import 'widgets/global_search_delegate.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('حدث خطأ: $e')),
          data: (stats) => _DashboardBody(stats: stats),
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  final DashboardStats stats;
  const _DashboardBody({required this.stats});

  Future<void> _generateMonthlyInvoices(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'توليد فواتير الشهر',
      message: 'هل تريد فحص كافة الاشتراكات وتوليد فواتير مسودة جديدة للاشتراكات المستحقة لهذا الشهر؟ لن يتم تكرار أي فواتير تم توليدها مسبقاً لنفس الشهر.',
      confirmLabel: 'بدء التوليد',
      cancelLabel: 'إلغاء',
      icon: Icons.autorenew_rounded,
    );
    if (confirmed != true || !context.mounted) return;

    final nav = Navigator.of(context, rootNavigator: true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repo = ref.read(invoiceRepositoryProvider);
      final createdIds = await repo.generateMonthlyInvoices();
      nav.pop();

      if (createdIds.isEmpty) {
        if (context.mounted) {
          AppSnackBar.showInfo(context, 'لا توجد اشتراكات مستحقة لتوليد فواتير جديدة لها هذا الشهر');
        }
      } else {
        ref.read(invoiceStatusFilterProvider.notifier).setFilter(InvoiceStatus.draft);
        if (context.mounted) {
          context.push('/invoices/drafts-review', extra: createdIds);
        }
      }
    } catch (e) {
      nav.pop();
      if (context.mounted) {
        AppSnackBar.showError(context, 'خطأ أثناء توليد الفواتير: $e');
      }
    }
  }

  Color _getStatusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return const Color(0xFF6B7280);
      case InvoiceStatus.sent:
        return const Color(0xFF2563EB);
      case InvoiceStatus.paid:
        return const Color(0xFF059669);
      case InvoiceStatus.partiallyPaid:
        return const Color(0xFFD97706);
      case InvoiceStatus.overdue:
        return const Color(0xFFDC2626);
      case InvoiceStatus.cancelled:
        return const Color(0xFF4B5563);
    }
  }

  String _getStatusLabel(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return 'مسودة';
      case InvoiceStatus.sent:
        return 'مرسلة';
      case InvoiceStatus.paid:
        return 'مدفوعة';
      case InvoiceStatus.partiallyPaid:
        return 'مدفوعة جزئياً';
      case InvoiceStatus.overdue:
        return 'متأخرة';
      case InvoiceStatus.cancelled:
        return 'ملغاة';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(companyStreamProvider);
    final isCompanyIncomplete = companyAsync.when(
      data: (company) =>
          company == null ||
          company.name.trim().isEmpty ||
          (company.name == 'شركتي' &&
              (company.phone == null || company.phone!.isEmpty) &&
              (company.address == null || company.address!.isEmpty)),
      loading: () => false,
      error: (err, stack) => false,
    );

    return CustomScrollView(
      slivers: [
        // ── App Bar مخصّص ──
        SliverAppBar(
          expandedHeight: 140,
          pinned: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded, color: Colors.white),
              tooltip: 'بحث شامل',
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: AppGlobalSearchDelegate(ref: ref),
                );
              },
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsetsDirectional.only(
                start: 20, bottom: 16),
            title: const Text(
              'لوحة المعلومات',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1F3A5F),
                    Color(0xFF2D5F8B),
                    Color(0xFF3A7BB8),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // دوائر تزيينية شفافة
                  Positioned(
                    top: -30,
                    left: -40,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -20,
                    right: -30,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    right: 20,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── المحتوى ──
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── بانر إعداد بيانات الشركة لأول تشغيل ──
              if (isCompanyIncomplete) _buildCompanyOnboardingBanner(context),

              // ── قسم المتأخرات العاجلة إن وُجدت ──
              _buildOverdueSection(context, ref),

              // ── صف البطاقات الرئيسية ──
              _buildMainCards(context),
              const SizedBox(height: 20),

              // ── إجراءات سريعة ──
              _buildQuickActions(context, ref),
              const SizedBox(height: 20),

              // ── تحصيلات الشهر ──
              _buildCollectionsCard(context),
              const SizedBox(height: 20),

              // ── آخر الفواتير ──
              _buildRecentInvoices(context, ref),
              const SizedBox(height: 20),

              // ── ملخص سريع ──
              _buildQuickSummary(context),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyOnboardingBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1F3A5F),
            Color(0xFF2D5F8B),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F3A5F).withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront_outlined, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أكمل إعداد بيانات شركتك',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'أضف اسم منشأتك، الشعار، ومعلومات الاتصال لتظهر تلقائياً في ترويسة الفواتير وسندات القبض.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1F3A5F),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    visualDensity: VisualDensity.compact,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text(
                    'إعداد بيانات الشركة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () {
                    context.go('/settings/company-setup');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCards(BuildContext context) {
    return Column(
      children: [
        // الصف الأول: إجمالي المستحق + المتأخرات
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF1F3A5F),
                iconBgColor: const Color(0xFF1F3A5F).withValues(alpha: 0.1),
                title: 'إجمالي المستحق',
                amounts: stats.totalOutstandingByCurrency,
                emptyLabel: '0.00',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.warning_amber_rounded,
                iconColor: const Color(0xFFDC2626),
                iconBgColor: const Color(0xFFDC2626).withValues(alpha: 0.1),
                title: 'المتأخرات',
                amounts: stats.overdueByCurrency,
                emptyLabel: '0.00',
                amountColor: stats.overdueByCurrency.isNotEmpty
                    ? const Color(0xFFDC2626)
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // الصف الثاني: تحصيلات الشهر + عدد العملاء
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.trending_up_rounded,
                iconColor: const Color(0xFF059669),
                iconBgColor: const Color(0xFF059669).withValues(alpha: 0.1),
                title: 'تحصيلات الشهر',
                amounts: stats.monthCollectionsByCurrency,
                emptyLabel: '0.00',
                amountColor: const Color(0xFF059669),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CountCard(
                icon: Icons.people_alt_rounded,
                iconColor: const Color(0xFF7C3AED),
                iconBgColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                title: 'عدد العملاء',
                count: stats.activeClientCount,
                subtitle: 'من ${stats.totalClientCount} إجمالي',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCollectionsCard(BuildContext context) {
    final hasCollections = stats.monthCollectionsByCurrency.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF059669),
            Color(0xFF047857),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'تحصيلات هذا الشهر',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasCollections)
            Text(
              'لا توجد تحصيلات حتى الآن',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            )
          else
            ...stats.monthCollectionsByCurrency.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  formatMoney(e.value, e.key),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverdueSection(BuildContext context, WidgetRef ref) {
    final overdueAsync = ref.watch(overdueInvoicesProvider);

    return overdueAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (overdueList) {
        if (overdueList.isEmpty) return const SizedBox.shrink();

        final now = DateTime.now();

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFCA5A5)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'متأخرات تتطلب اهتماماً',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${overdueList.length} متأخرة',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...overdueList.map((item) {
                final daysOverdue = item.invoice.dueDate != null
                    ? now.difference(item.invoice.dueDate!).inDays
                    : 0;
                final overdueText = daysOverdue <= 0
                    ? 'مستحقة اليوم'
                    : 'متأخرة منذ $daysOverdue ${daysOverdue == 1 ? "يوم" : daysOverdue == 2 ? "يومين" : daysOverdue <= 10 ? "أيام" : "يوماً"}';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.push('/invoices/${item.invoice.id}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        item.invoice.number,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.dark,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          item.clientName,
                                          style: TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule, size: 12, color: Color(0xFFDC2626)),
                                      const SizedBox(width: 4),
                                      Text(
                                        overdueText,
                                        style: const TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Text(' • ', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                      Text(
                                        formatMoney(item.invoice.totalMinor, item.invoice.currency),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Color(0xFF991B1B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.payment, size: 14),
                              label: const Text(
                                'سداد',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              onPressed: () {
                                context.push('/invoices/${item.invoice.id}/pay');
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt_rounded, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            const Text(
              'إجراءات سريعة',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.dark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.post_add_rounded,
                label: 'فاتورة جديدة',
                color: const Color(0xFF1F3A5F),
                onTap: () => context.push('/invoices/new'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.person_add_alt_1_rounded,
                label: 'عميل جديد',
                color: const Color(0xFF7C3AED),
                onTap: () => context.push('/clients/add'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.autorenew_rounded,
                label: 'توليد الفواتير',
                color: const Color(0xFF059669),
                onTap: () => _generateMonthlyInvoices(context, ref),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentInvoices(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentInvoicesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.history_rounded, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'آخر الفواتير',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dark,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => context.go('/invoices'),
              icon: const Icon(Icons.arrow_back, size: 14),
              label: const Text(
                'عرض الكل',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        recentAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, stack) => Text('خطأ في تحميل الفواتير: $err'),
          data: (invoices) {
            if (invoices.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.muted),
                    const SizedBox(height: 8),
                    Text(
                      'لا توجد فواتير مسجلة بعد',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: invoices.map((item) {
                final status = getEffectiveInvoiceStatus(item.invoice);
                final statusColor = _getStatusColor(status);
                final statusLabel = _getStatusLabel(status);
                final dateStr =
                    '${item.invoice.issueDate.year}/${item.invoice.issueDate.month.toString().padLeft(2, '0')}/${item.invoice.issueDate.day.toString().padLeft(2, '0')}';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => context.push('/invoices/${item.invoice.id}'),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.receipt_outlined,
                                color: statusColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        item.invoice.number,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.dark,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          item.clientName,
                                          style: TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Text(' • ', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                      Text(
                                        dateStr,
                                        style: TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatMoney(item.invoice.totalMinor, item.invoice.currency),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.dark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickSummary(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_rounded,
                color: AppColors.accent,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'ملخص سريع',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _SummaryRow(
            label: 'فواتير معلّقة',
            value: '${stats.pendingInvoiceCount}',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'فواتير متأخرة',
            value: '${stats.overdueInvoiceCount}',
            icon: Icons.schedule_rounded,
            color: const Color(0xFFDC2626),
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'عملاء نشطون',
            value: '${stats.activeClientCount}',
            icon: Icons.person_rounded,
            color: const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// بطاقة مبالغ (تدعم عملات متعددة)
// ─────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final Map<String, int> amounts;
  final String emptyLabel;
  final Color? amountColor;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.amounts,
    required this.emptyLabel,
    this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasAmounts = amounts.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          if (!hasAmounts)
            Text(
              emptyLabel,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: amountColor ?? AppColors.dark,
              ),
            )
          else
            ...amounts.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    formatMoney(e.value, e.key),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: amountColor ?? AppColors.dark,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// بطاقة عدد (عدد العملاء)
// ─────────────────────────────────────────────────
class _CountCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final int count;
  final String subtitle;

  const _CountCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.count,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// صفّ ملخّص (أيقونة + نص + قيمة)
// ─────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.muted,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// زر إجراء سريع
// ─────────────────────────────────────────────────
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dark,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
