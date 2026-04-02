import { mutation, query } from './_generated/server';
import { v } from 'convex/values';
import { authComponent } from './auth';

async function requireAuth(ctx: any): Promise<string> {
  const user = await authComponent.getAuthUser(ctx);
  if (!user) throw new Error('Not authenticated');
  return (user._id as unknown as string).toString();
}

export const getByUser = query({
  args: { userId: v.string() },
  handler: async (ctx, args) => {
    const memberships = await ctx.db
      .query('groupMembers')
      .withIndex('by_user', (q) => q.eq('userId', args.userId))
      .collect();

    const groups = await Promise.all(
      memberships.map((m) => ctx.db.get(m.groupId)),
    );

    return groups.filter((g) => g !== null);
  },
});

export const getById = query({
  args: { id: v.id('groups') },
  handler: async (ctx, args) => {
    return await ctx.db.get(args.id);
  },
});

export const getByInviteCode = query({
  args: { inviteCode: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query('groups')
      .withIndex('by_invite_code', (q) => q.eq('inviteCode', args.inviteCode))
      .first();
  },
});

function generateInviteCode(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

export const create = mutation({
  args: {
    name: v.string(),
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);
    const inviteCode = generateInviteCode();

    const groupId = await ctx.db.insert('groups', {
      name: args.name,
      createdBy: userId,
      members: [userId],
      inviteCode,
      createdAt: Date.now(),
    });

    await ctx.db.insert('groupMembers', {
      groupId,
      userId,
      joinedAt: Date.now(),
    });

    return groupId;
  },
});

export const join = mutation({
  args: {
    groupId: v.id('groups'),
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);
    const group = await ctx.db.get(args.groupId);
    if (!group) throw new Error('Group not found');

    if (group.members.includes(userId)) {
      return;
    }

    await ctx.db.patch(args.groupId, {
      members: [...group.members, userId],
    });

    await ctx.db.insert('groupMembers', {
      groupId: args.groupId,
      userId,
      joinedAt: Date.now(),
    });
  },
});

export const leave = mutation({
  args: {
    groupId: v.id('groups'),
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);
    const group = await ctx.db.get(args.groupId);
    if (!group) throw new Error('Group not found');

    await ctx.db.patch(args.groupId, {
      members: group.members.filter((id) => id !== userId),
    });

    const membership = await ctx.db
      .query('groupMembers')
      .withIndex('by_group', (q) => q.eq('groupId', args.groupId))
      .filter((q) => q.eq(q.field('userId'), userId))
      .first();

    if (membership) {
      await ctx.db.delete(membership._id);
    }
  },
});
