import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_cache_service.dart';
import 'convex_service.dart';

enum SyncStatus { idle, syncing, offline, error }

class SyncState {
  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final String? error;
  final int pendingCount;

  SyncState({
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

class SyncService {
  final LocalCacheService _cache;
  final ConvexService _convex;
  final StateController<SyncState> _stateController;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _periodicSyncTimer;

  SyncService(this._cache, this._convex, this._stateController) {
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

    // Initial sync attempt
    syncNow();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isOffline = results.contains(ConnectivityResult.none);

    if (isOffline) {
      _stateController.state = _stateController.state.copyWith(
        status: SyncStatus.offline,
      );
    } else if (_stateController.state.status == SyncStatus.offline) {
      syncNow();
    }
  }

  Future<void> syncNow() async {
    if (_stateController.state.status == SyncStatus.syncing) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      _stateController.state = _stateController.state.copyWith(
        status: SyncStatus.offline,
      );
      return;
    }

    _stateController.state = _stateController.state.copyWith(
      status: SyncStatus.syncing,
    );

    try {
      await _pullRemoteChanges();
      await _pushLocalChanges();
      await _cache.cleanupExpiredData();

      final pendingCount = _cache.getPendingMutations().length;
      _stateController.state = SyncState(
        status: SyncStatus.idle,
        lastSyncedAt: DateTime.now(),
        pendingCount: pendingCount,
      );
    } catch (e) {
      _stateController.state = _stateController.state.copyWith(
        status: SyncStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> _pullRemoteChanges() async {
    final lastSync = _cache.getSetting<String>('lastSync');
    final lastSyncTime = lastSync != null
        ? DateTime.tryParse(lastSync)?.millisecondsSinceEpoch ?? 0
        : 0;

    try {
      final remoteExpenses = await _convex.query('expenses:getUpdatedSince', {
        'since': lastSyncTime,
      });

      if (remoteExpenses != null && remoteExpenses is List) {
        for (final remoteExpense in remoteExpenses) {
          final id = remoteExpense['_id'] as String;
          final localExpense = _cache.getExpense(id);

          if (localExpense == null) {
            await _cache.saveExpense({
              'id': id,
              ...Map<String, dynamic>.from(remoteExpense),
              'convexId': id,
              'syncStatus': 'synced',
            });
          } else {
            final remoteUpdatedAt = DateTime.fromMillisecondsSinceEpoch(
              remoteExpense['updatedAt'] as int? ??
                  remoteExpense['createdAt'] as int,
            );
            final localUpdatedAtStr = localExpense['updatedAt'] as String?;
            final localUpdatedAt = localUpdatedAtStr != null
                ? DateTime.tryParse(localUpdatedAtStr)
                : null;

            if (localUpdatedAt == null ||
                remoteUpdatedAt.isAfter(localUpdatedAt)) {
              await _cache.saveExpense({
                'id': id,
                ...Map<String, dynamic>.from(remoteExpense),
                'convexId': id,
                'syncStatus': 'synced',
              });
            }
          }
        }
      }

      await _cache.saveSetting('lastSync', DateTime.now().toIso8601String());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _pushLocalChanges() async {
    final pending = _cache.getPendingMutations();

    for (final mutation in pending) {
      final type = mutation['type'] as String;
      final collection = mutation['collection'] as String;
      final recordId = mutation['recordId'] as String;
      final payload = mutation['payload'] as Map<String, dynamic>;
      final retryCount = mutation['retryCount'] as int? ?? 0;

      try {
        switch (type) {
          case 'create':
            final convexId = await _convex.mutation(
              '$collection:create',
              Map<String, dynamic>.from(payload),
            );

            if (convexId != null) {
              final localExpense = _cache.getExpense(recordId);
              if (localExpense != null) {
                await _cache.saveExpense({
                  ...localExpense,
                  'convexId': convexId,
                  'syncStatus': 'synced',
                });
              }
              await _cache.removePendingMutation(mutation['id'] as String);
            }
            break;

          case 'update':
            final localExpense = _cache.getExpense(recordId);
            final convexId = localExpense?['convexId'];

            if (convexId != null) {
              await _convex.mutation('$collection:update', {
                'id': convexId,
                ...Map<String, dynamic>.from(payload),
              });
              await _cache.removePendingMutation(mutation['id'] as String);
            }
            break;

          case 'delete':
            final localExpense = _cache.getExpense(recordId);
            final deleteConvexId = localExpense?['convexId'];

            if (deleteConvexId != null) {
              await _convex.mutation('$collection:remove', {
                'id': deleteConvexId,
              });
            }
            await _cache.deleteExpense(recordId);
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

  int getPendingCount() {
    return _cache.getPendingMutations().length;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
  }
}
