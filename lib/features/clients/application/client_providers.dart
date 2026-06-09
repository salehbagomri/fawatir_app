import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/features/clients/data/client_repository.dart';
import 'package:fawatir/features/payments/data/payment_repository.dart';

final clientSearchProvider = NotifierProvider.autoDispose<ClientSearchNotifier, String>(
  ClientSearchNotifier.new,
);

class ClientSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String q) => state = q;
}

final clientsStreamProvider = StreamProvider.autoDispose<List<Client>>((ref) {
  final q = ref.watch(clientSearchProvider);
  return ref.watch(clientRepositoryProvider).watchClients(search: q.isEmpty ? null : q);
});

final clientByIdProvider = FutureProvider.autoDispose.family<Client?, int>((ref, id) {
  return ref.watch(clientRepositoryProvider).getClient(id);
});

final clientBalanceProvider = FutureProvider.autoDispose.family<int, int>((ref, clientId) {
  return ref.watch(paymentRepositoryProvider).clientAccountBalanceMinor(clientId);
});

