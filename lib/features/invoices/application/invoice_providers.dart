import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/features/clients/data/client_repository.dart';

final activeClientsProvider = StreamProvider.autoDispose<List<Client>>((ref) {
  return ref.watch(clientRepositoryProvider).watchClients().map(
    (clients) => clients.where((c) => c.isActive).toList(),
  );
});
