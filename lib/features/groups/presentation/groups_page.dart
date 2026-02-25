import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/constants.dart';
import '../domain/group.dart';
import '../../auth/data/auth_repository.dart';

class GroupNotifier extends StateNotifier<List<Group>> {
  GroupNotifier() : super([]);

  String generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final code = StringBuffer();
    for (int i = 0; i < 6; i++) {
      code.write(chars[DateTime.now().millisecondsSinceEpoch % chars.length]);
    }
    return code.toString();
  }

  void createGroup(String name, String userId) {
    final group = Group(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      createdBy: userId,
      members: [userId],
      inviteCode: generateInviteCode(),
      createdAt: DateTime.now(),
    );
    state = [...state, group];
  }

  void joinGroup(Group group, String userId) {
    if (group.members.contains(userId)) return;

    final updatedGroup = Group(
      id: group.id,
      name: group.name,
      createdBy: group.createdBy,
      members: [...group.members, userId],
      inviteCode: group.inviteCode,
      createdAt: group.createdAt,
    );

    state = state.map((g) => g.id == group.id ? updatedGroup : g).toList();
  }

  void leaveGroup(String groupId, String userId) {
    state = state.where((g) {
      if (g.id == groupId) {
        final updatedMembers = g.members.where((m) => m != userId).toList();
        if (updatedMembers.isEmpty) {
          return false;
        }
        return true;
      }
      return true;
    }).toList();
  }
}

final groupsProvider = StateNotifierProvider<GroupNotifier, List<Group>>((ref) {
  return GroupNotifier();
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
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final currentUser = ref.read(currentUserProvider);
                if (currentUser != null) {
                  ref
                      .read(groupsProvider.notifier)
                      .createGroup(controller.text, currentUser.id);
                }
                Navigator.pop(context);
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
            onPressed: () {
              if (controller.text.length == 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Group not found')),
                );
                Navigator.pop(context);
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
