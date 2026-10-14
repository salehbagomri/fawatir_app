import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fawatir/app/theme.dart';
import 'package:fawatir/core/money.dart';
import 'package:fawatir/data/db/tables.dart';
import 'package:fawatir/features/clients/application/client_providers.dart';
import 'package:fawatir/features/invoices/application/invoice_providers.dart';
import 'package:fawatir/features/invoices/data/invoice_repository.dart';

class GeneratedDraftsScreen extends ConsumerStatefulWidget {
  final List<int> invoiceIds;

  const GeneratedDraftsScreen({
    super.key,
    required this.invoiceIds,
  });

  @override
  ConsumerState<GeneratedDraftsScreen> createState() =>
      _GeneratedDraftsScreenState();
}

class _GeneratedDraftsScreenState extends ConsumerState<GeneratedDraftsScreen> {
  bool _isProcessing = false;

  Future<void> _sendAllInvoices() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.send_rounded, color: Colors.blue),
              SizedBox(width: 8),
              Text('تأكيد اعتماد الكل'),
            ],
          ),
          content: Text(
            'هل أنت متأكد من اعتماد وإرسال جميع الفواتير المسودة (${widget.invoiceIds.length} فاتورة)؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء', style: TextStyle(color: AppColors.muted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('نعم، اعتماد الكل'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isProcessing = true;
    });

    final repo = ref.read(invoiceRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      for (final id in widget.invoiceIds) {
        await repo.updateInvoiceStatus(id, InvoiceStatus.sent);
        ref.invalidate(invoiceByIdProvider(id));
      }
      ref.invalidate(invoicesListProvider);

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('تم اعتماد وإرسال ${widget.invoiceIds.length} فاتورة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(); // Go back to invoices list
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الاعتماد: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _sendSingleInvoice(int invoiceId) async {
    setState(() {
      _isProcessing = true;
    });

    final repo = ref.read(invoiceRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await repo.updateInvoiceStatus(invoiceId, InvoiceStatus.sent);
      ref.invalidate(invoiceByIdProvider(invoiceId));
      ref.invalidate(invoicesListProvider);

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('تم اعتماد الفاتورة وتحويلها إلى مرسلة'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('مراجعة المسودات المولّدة (${widget.invoiceIds.length})'),
          actions: [
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                  ),
                ),
              )
            else if (widget.invoiceIds.isNotEmpty)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                icon: const Icon(Icons.done_all, size: 20),
                label: const Text('اعتماد الكل', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _sendAllInvoices,
              ),
          ],
        ),
        body: widget.invoiceIds.isEmpty
            ? const Center(
                child: Text('لا توجد فواتير للمراجعة', style: TextStyle(color: AppColors.muted)),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: widget.invoiceIds.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final id = widget.invoiceIds[index];
                  final invoiceAsync = ref.watch(invoiceByIdProvider(id));

                  return invoiceAsync.when(
                    loading: () => const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (err, _) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('خطأ في تحميل الفاتورة $id: $err', style: const TextStyle(color: Colors.red)),
                      ),
                    ),
                    data: (invoice) {
                      if (invoice == null) {
                        return const SizedBox.shrink();
                      }

                      final clientAsync = ref.watch(clientByIdProvider(invoice.clientId));
                      final isDraft = invoice.status == InvoiceStatus.draft;

                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.line.withValues(alpha: 0.6)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.receipt_outlined, color: AppColors.accent, size: 20),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        invoice.number,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDraft
                                          ? Colors.grey.withValues(alpha: 0.15)
                                          : Colors.blue.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isDraft ? 'مسودة' : 'مرسلة',
                                      style: TextStyle(
                                        color: isDraft ? Colors.grey.shade800 : Colors.blue.shade800,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'العميل',
                                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                                      ),
                                      const SizedBox(height: 2),
                                      clientAsync.when(
                                        loading: () => const Text('جارٍ التحميل...'),
                                        error: (err, stack) => const Text('خطأ'),
                                        data: (c) => Text(
                                          c?.name ?? 'عميل غير معروف',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'المبلغ',
                                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        formatMoney(invoice.totalMinor, invoice.currency),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.dark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor: AppColors.accent,
                                      side: const BorderSide(color: AppColors.line),
                                    ),
                                    icon: const Icon(Icons.remove_red_eye, size: 16),
                                    label: const Text('عرض التفاصيل'),
                                    onPressed: () => context.push('/invoices/${invoice.id}'),
                                  ),
                                  if (isDraft) ...[
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        foregroundColor: AppColors.accent,
                                        side: const BorderSide(color: AppColors.line),
                                      ),
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text('تعديل'),
                                      onPressed: () => context.push('/invoices/${invoice.id}/edit'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: Colors.blue.shade700,
                                        foregroundColor: Colors.white,
                                      ),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('اعتماد'),
                                      onPressed: () => _sendSingleInvoice(invoice.id),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
