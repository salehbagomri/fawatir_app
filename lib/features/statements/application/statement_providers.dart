import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/statement_repository.dart';

final statementProvider = FutureProvider.autoDispose
    .family<Statement, ({int clientId, DateTime? from, DateTime? to})>(
  (ref, p) => ref.watch(statementRepositoryProvider)
      .buildStatement(p.clientId, from: p.from, to: p.to),
);
