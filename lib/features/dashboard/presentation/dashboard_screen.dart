import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/core/money.dart';
import '../data/dashboard_repository.dart';

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

class _DashboardBody extends StatelessWidget {
  final DashboardStats stats;
  const _DashboardBody({required this.stats});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── App Bar مخصّص ──
        SliverAppBar(
          expandedHeight: 140,
          pinned: true,
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
              // ── صف البطاقات الرئيسية ──
              _buildMainCards(context),
              const SizedBox(height: 20),

              // ── تحصيلات الشهر ──
              _buildCollectionsCard(context),
              const SizedBox(height: 20),

              // ── ملخص سريع ──
              _buildQuickSummary(context),
            ]),
          ),
        ),
      ],
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
