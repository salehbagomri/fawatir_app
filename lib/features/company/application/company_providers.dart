import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/features/company/data/company_repository.dart';

final companyStreamProvider = StreamProvider<Company?>(
  (ref) => ref.watch(companyRepositoryProvider).watchCompany(),
);
