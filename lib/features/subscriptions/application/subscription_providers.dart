import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fawatir/data/db/database.dart';
import '../data/subscription_repository.dart';

final clientSubscriptionsProvider = StreamProvider.autoDispose
    .family<List<Subscription>, int>((ref, clientId) =>
        ref.watch(subscriptionRepositoryProvider)
           .watchSubscriptions(clientId));

final subscriptionByIdProvider = FutureProvider.autoDispose
    .family<Subscription?, int>((ref, subId) =>
        ref.watch(subscriptionRepositoryProvider)
           .getSubscription(subId));
