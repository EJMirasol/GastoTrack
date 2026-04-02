import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_cache_service.dart';
import 'convex_service.dart';
import '../../features/auth/data/auth_repository.dart';

enum SyncStatus { idle, syncing, offline, error }

class SyncState {
  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final String? error;
  final int pendingCount;

  const SyncState({
    required this.status,
    this.lastSyncedAt,
    this.error,
    this.pendingCount = 0,
  });

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncedAt,
    String? error,
    int? pendingCount,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      error: error,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }
}

final syncStateProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final cache = ref.watch(localCacheServiceProvider);
  final convex = ref.watch(convexServiceProvider);
  return SyncNotifier(cache, convex);
});

class SyncNotifier extends StateNotifier<SyncState> {
  final LocalCacheService _cache;
  final ConvexService _convex;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _periodicSyncTimer;

  SyncNotifier(this._cache, this._convex)
    : super(const SyncState(status: SyncStatus.idle)) {
    _initialize();
  }

  void _initialize() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    _periodicSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => syncNow(),
    );
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isOffline = results.contains(ConnectivityResult.none);

    if (isOffline) {
      state = state.copyWith(status: SyncStatus.offline);
    } else if (state.status == SyncStatus.offline) {
      syncNow();
    }
  }

  Future<void> syncNow() async {
    if (state.status == SyncStatus.syncing) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      state = state.copyWith(status: SyncStatus.offline);
      return;
    }

    state = state.copyWith(status: SyncStatus.syncing);

    try {
      await _pullRemoteChanges();
      await _pushLocalChanges();
      await _cache.cleanupExpiredData();

      final pendingCount = _cache.getPendingMutations().length;
      state = SyncState(
        status: SyncStatus.idle,
        lastSyncedAt: DateTime.now(),
        pendingCount: pendingCount,
      );
    } catch (e) {
      state = state.copyWith(status: SyncStatus.error, error: e.toString());
    }
  }

  Future<void> _pullRemoteChanges() async {
    final userId = _cache.getSetting<String>('current_user_id');
    if (userId == null) return;

    await _pullTransactions(userId);
    await _pullGroups(userId);
    await _pullBudgets(userId);

    await _cache.saveSetting('lastSync', DateTime.now().toIso8601String());
  }

  Future<void> _pullTransactions(String userId) async {
    try {
      final result = await _convex.query('transactions:getByUser', {
        'userId': userId,
      });
      final remoteExpenses = result['value'] as List<dynamic>? ?? [];

      for (final remote in remoteExpenses) {
        final map = remote as Map<String, dynamic>;
        final id = map['_id'] as String;
        await _cache.saveTransaction({
          'id': id,
          'convexId': id,
          'syncStatus': 'synced',
          'amount': map['amount'],
          'categoryId': map['categoryId'] as String,
          'userId': map['userId'] as String,
          'groupId': map['groupId'] as String?,
          'description': map['description'] as String?,
          'date': map['date'],
          'type': map['type'] as String,
          'isRecurring': map['isRecurring'] as bool? ?? false,
          'createdAt': map['createdAt'],
        });
      }
    } catch (_) {}
  }

  Future<void> _pullGroups(String userId) async {
    try {
      final result = await _convex.query('groups:getByUser', {
        'userId': userId,
      });
      final remoteGroups = result['value'] as List<dynamic>? ?? [];

      for (final remote in remoteGroups) {
        final map = remote as Map<String, dynamic>;
        final id = map['_id'] as String;
        await _cache.saveGroup({
          'id': id,
          'convexId': id,
          'syncStatus': 'synced',
          'name': map['name'] as String,
          'createdBy': map['createdBy'] as String,
          'members': List<String>.from(map['members'] as List),
          'inviteCode': map['inviteCode'] as String,
          'createdAt': map['createdAt'],
        });
      }
    } catch (_) {}
  }

  Future<void> _pullBudgets(String userId) async {
    try {
      final result = await _convex.query('budgets:getByUser', {
        'userId': userId,
      });
      final remoteBudgets = result['value'] as List<dynamic>? ?? [];

      for (final remote in remoteBudgets) {
        final map = remote as Map<String, dynamic>;
        final id = map['_id'] as String;
        await _cache.saveBudget({
          'id': id,
          'convexId': id,
          'syncStatus': 'synced',
          'userId': map['userId'] as String,
          'categoryId': map['categoryId'] as String?,
          'amount': map['amount'],
          'period': map['period'] as String,
          'createdAt': map['createdAt'],
        });
      }
    } catch (_) {}
  }

  Future<void> _pushLocalChanges() async {
    final pending = _cache.getPendingMutations();

    for (final mutation in pending) {
      final type = mutation['type'] as String;
      final collection = mutation['collection'] as String;
      final recordId = mutation['recordId'] as String;
      final payload = Map<String, dynamic>.from(
        mutation['payload'] as Map? ?? {},
      );
      final retryCount = mutation['retryCount'] as int? ?? 0;

      try {
        switch (type) {
          case 'create':
            final result = await _convex.mutation(
              '$collection:create',
              payload,
            );
            final convexId = result['value'] as String?;
            if (convexId != null) {
              _updateConvexId(collection, recordId, convexId);
            }
            await _cache.removePendingMutation(mutation['id'] as String);
            break;

          case 'update':
            final convexId = _getConvexId(collection, recordId);
            if (convexId != null) {
              await _convex.mutation('$collection:update', {
                'id': convexId,
                ...payload,
              });
              await _cache.removePendingMutation(mutation['id'] as String);
            }
            break;

          case 'delete':
            final deleteConvexId = _getConvexId(collection, recordId);
            if (deleteConvexId != null) {
              await _convex.mutation('$collection:remove', {
                'id': deleteConvexId,
              });
            }
            _deleteLocalRecord(collection, recordId);
            await _cache.removePendingMutation(mutation['id'] as String);
            break;
        }
      } catch (e) {
        final newRetryCount = retryCount + 1;

        if (newRetryCount >= 5) {
          await _cache.removePendingMutation(mutation['id'] as String);
        } else {
          await _cache.updateMutationRetry(
            mutation['id'] as String,
            newRetryCount,
            e.toString(),
          );
        }
      }
    }
  }

  String? _getConvexId(String collection, String recordId) {
    switch (collection) {
      case 'transactions':
        return _cache.getTransaction(recordId)?['convexId'] as String?;
      case 'groups':
        return _cache.getGroup(recordId)?['convexId'] as String?;
      case 'budgets':
        return _cache.getBudget(recordId)?['convexId'] as String?;
      default:
        return null;
    }
  }

  void _updateConvexId(String collection, String recordId, String convexId) {
    switch (collection) {
      case 'transactions':
        final local = _cache.getTransaction(recordId);
        if (local != null) {
          _cache.deleteTransaction(recordId);
          _cache.saveTransaction({
            ...local,
            'id': convexId,
            'convexId': convexId,
            'syncStatus': 'synced',
          });
        }
        break;
      case 'groups':
        final local = _cache.getGroup(recordId);
        if (local != null) {
          _cache.deleteGroup(recordId);
          _cache.saveGroup({
            ...local,
            'id': convexId,
            'convexId': convexId,
            'syncStatus': 'synced',
          });
        }
        break;
      case 'budgets':
        final local = _cache.getBudget(recordId);
        if (local != null) {
          _cache.deleteBudget(recordId);
          _cache.saveBudget({
            ...local,
            'id': convexId,
            'convexId': convexId,
            'syncStatus': 'synced',
          });
        }
        break;
    }
  }

  void _deleteLocalRecord(String collection, String recordId) {
    switch (collection) {
      case 'transactions':
        _cache.deleteTransaction(recordId);
        break;
      case 'groups':
        _cache.deleteGroup(recordId);
        break;
      case 'budgets':
        _cache.deleteBudget(recordId);
        break;
    }
  }

  int getPendingCount() {
    return _cache.getPendingMutations().length;
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
    super.dispose();
  }
}
