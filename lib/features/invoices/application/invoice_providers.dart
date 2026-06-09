import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/data/db/tables.dart';
import 'package:fawatir/features/clients/data/client_repository.dart';
import 'package:fawatir/features/invoices/data/invoice_repository.dart';

final activeClientsProvider = StreamProvider.autoDispose<List<Client>>((ref) {
  return ref.watch(clientRepositoryProvider).watchClients().map(
    (clients) => clients.where((c) => c.isActive).toList(),
  );
});

final invoiceStatusFilterProvider = NotifierProvider.autoDispose<InvoiceStatusFilterNotifier, InvoiceStatus?>(
  InvoiceStatusFilterNotifier.new,
);

class InvoiceStatusFilterNotifier extends Notifier<InvoiceStatus?> {
  @override
  InvoiceStatus? build() => null;

  void setFilter(InvoiceStatus? status) {
    state = status;
  }
}

final invoicesListProvider = StreamProvider.autoDispose<List<Invoice>>((ref) {
  final status = ref.watch(invoiceStatusFilterProvider);
  return ref.watch(invoiceRepositoryProvider).watchInvoices(status: status);
});

final invoiceByIdProvider =
    FutureProvider.autoDispose.family<Invoice?, int>((ref, id) =>
        ref.watch(invoiceRepositoryProvider).getInvoice(id));

final invoiceItemsProvider = FutureProvider.autoDispose
    .family<List<InvoiceItem>, int>((ref, id) =>
        ref.watch(invoiceRepositoryProvider).getItems(id));

final clientsMapProvider = StreamProvider.autoDispose<Map<int, String>>((ref) =>
    ref.watch(clientRepositoryProvider).watchClients()
       .map((l) => {for (final c in l) c.id: c.name}));

final clientInvoicesProvider = StreamProvider.autoDispose.family<List<Invoice>, int>((ref, clientId) {
  return ref.watch(invoiceRepositoryProvider).watchInvoices(clientId: clientId);
});
