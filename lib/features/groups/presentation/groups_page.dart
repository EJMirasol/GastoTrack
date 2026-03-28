import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../core/services/convex_service.dart';
import '../domain/group.dart';
import '../../auth/data/auth_repository.dart';

class GroupNotifier extends StateNotifier<List<Group>> {
  final LocalCacheService _cache;
  final ConvexService _convex;

  GroupNotifier(this._cache, this._convex) : super([]);

  Future<void> loadForUser(String userId) async {
    final cachedGroups = _cache.getGroupsForUser(userId);
    if (cachedGroups.isNotEmpty) {
      state = cachedGroups.map((g) => Group.fromJson(g)).toList();
    }

    try {
      final result = await _convex.query('groups:getByUser', {
        'userId': userId,
      });
      final remoteGroups = result['value'] as List<dynamic>? ?? [];

      final groups = remoteGroups.map((g) {
        final map = g as Map<String, dynamic>;
        return Group(
          id: map['_id'] as String,
          name: map['name'] as String,
          createdBy: map['createdBy'] as String,
          members: List<String>.from(map['members'] as List),
          inviteCode: map['inviteCode'] as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            map['createdAt'] as int,
          ),
        );
      }).toList();

      for (final group in groups) {
        await _cache.saveGroup({
          ...group.toJson(),
          'convexId': group.id,
          'syncStatus': 'synced',
        });
      }
      state = groups;
    } catch (_) {}
  }

  Future<void> createGroup(String name, String userId) async {
    final localId = DateTime.now().millisecondsSinceEpoch.toString();
    final group = Group(
      id: localId,
      name: name,
      createdBy: userId,
      members: [userId],
      inviteCode: '',
      createdAt: DateTime.now(),
    );
    await _cache.saveGroup(group.toJson());
    state = [...state, group];

    try {
      final result = await _convex.mutation('groups:create', {'name': name});
      final convexId = result['value'] as String?;
      if (convexId != null) {
        await _cache.saveGroup({
          ...group.toJson(),
          'id': convexId,
          'convexId': convexId,
          'syncStatus': 'synced',
        });
        final updatedGroup = Group(
          id: convexId,
          name: name,
          createdBy: userId,
          members: [userId],
          inviteCode: group.inviteCode,
          createdAt: group.createdAt,
        );
        state = state.map((g) => g.id == localId ? updatedGroup : g).toList();
      }
    } catch (_) {
      await _cache.addToSyncQueue({
        'id': localId,
        'type': 'create',
        'collection': 'groups',
        'recordId': localId,
        'payload': {'name': name},
      });
    }
  }

  Future<Group?> findByInviteCode(String code) async {
    try {
      final result = await _convex.query('groups:getByInviteCode', {
        'inviteCode': code,
      });
      final data = result['value'];
      if (data == null) return null;
      final map = data as Map<String, dynamic>;
      return Group(
        id: map['_id'] as String,
        name: map['name'] as String,
        createdBy: map['createdBy'] as String,
        members: List<String>.from(map['members'] as List),
        inviteCode: map['inviteCode'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> joinGroup(String inviteCode, String userId) async {
    try {
      final group = await findByInviteCode(inviteCode);
      if (group == null) return false;

      await _convex.mutation('groups:join', {'groupId': group.id});
      await loadForUser(userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> leaveGroup(String groupId, String userId) async {
    final group = state.where((g) => g.id == groupId).firstOrNull;
    if (group == null) return;

    final updatedMembers = group.members.where((m) => m != userId).toList();

    if (updatedMembers.isEmpty) {
      await _cache.deleteGroup(groupId);
      state = state.where((g) => g.id != groupId).toList();
    } else {
      final updatedGroup = Group(
        id: group.id,
        name: group.name,
        createdBy: group.createdBy,
        members: updatedMembers,
        inviteCode: group.inviteCode,
        createdAt: group.createdAt,
      );
      await _cache.saveGroup(updatedGroup.toJson());
      state = state.map((g) => g.id == groupId ? updatedGroup : g).toList();
    }

    try {
      await _convex.mutation('groups:leave', {'groupId': groupId});
    } catch (_) {
      await _cache.addToSyncQueue({
        'id': '${groupId}_leave',
        'type': 'delete',
        'collection': 'groups',
        'recordId': groupId,
        'payload': {'userId': userId},
      });
    }
  }
}

final groupsProvider = StateNotifierProvider<GroupNotifier, List<Group>>((ref) {
  final cache = ref.watch(localCacheServiceProvider);
  final convex = ref.watch(convexServiceProvider);
  return GroupNotifier(cache, convex);
});

class GroupsPage extends ConsumerStatefulWidget {
  const GroupsPage({super.key});

  @override
  ConsumerState<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends ConsumerState<GroupsPage> {
  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateGroupDialog(context),
          ),
        ],
      ),
      body: groups.isEmpty
          ? const _EmptyGroupsState()
          : ListView.builder(
              padding: const EdgeInsets.all(AppSizes.md),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return _GroupCard(
                  group: group,
                  currentUserId: currentUser?.id ?? '',
                  onTap: () => context.push('/groups/${group.id}'),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showJoinGroupDialog(context),
        icon: const Icon(Icons.group_add),
        label: const Text('Join Group'),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Group Name',
            hintText: 'e.g., Trip to Paris',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final currentUser = ref.read(currentUserProvider);
                if (currentUser != null) {
                  await ref
                      .read(groupsProvider.notifier)
                      .createGroup(controller.text, currentUser.id);
                }
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinGroupDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Invite Code',
                hintText: 'Enter 6-character code',
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.length == 6) {
                final currentUser = ref.read(currentUserProvider);
                if (currentUser == null) return;

                final success = await ref
                    .read(groupsProvider.notifier)
                    .joinGroup(controller.text.toUpperCase(), currentUser.id);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success ? 'Joined group!' : 'Group not found',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

class _EmptyGroupsState extends StatelessWidget {
  const _EmptyGroupsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppSizes.md),
          Text('No groups yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSizes.xs),
          Text(
            'Create a group to start sharing expenses',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.currentUserId,
    this.onTap,
  });

  final Group group;
  final String currentUserId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isCreator = group.createdBy == currentUserId;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Text(
            group.name[0].toUpperCase(),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(group.name),
        subtitle: Text(
          '${group.members.length} member${group.members.length == 1 ? '' : 's'}',
        ),
        trailing: isCreator
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Admin',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
