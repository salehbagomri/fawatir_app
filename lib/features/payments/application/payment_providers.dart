import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/features/payments/data/payment_repository.dart';

/// المتبقي على الفاتورة بوحدات العملة الصغرى (المبلغ × 100).
final invoiceRemainingProvider =
    FutureProvider.autoDispose.family<int, int>((ref, invoiceId) {
  return ref.watch(paymentRepositoryProvider).invoiceRemainingMinor(invoiceId);
});

/// قائمة التحصيلات المرتبطة بفاتورة محددة بتحديث حي.
final invoicePaymentsProvider =
    StreamProvider.autoDispose.family<List<Payment>, int>((ref, invoiceId) {
  return ref.watch(paymentRepositoryProvider).watchPayments(invoiceId: invoiceId);
});

/// تحصيل محدد بالمعرّف.
final paymentByIdProvider =
    FutureProvider.autoDispose.family<Payment?, int>((ref, id) {
  return ref.watch(paymentRepositoryProvider).getPayment(id);
});
