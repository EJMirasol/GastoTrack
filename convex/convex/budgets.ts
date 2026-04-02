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
    return await ctx.db
      .query('budgets')
      .withIndex('by_user', (q) => q.eq('userId', args.userId))
      .collect();
  },
});

export const getByUserAndCategory = query({
  args: {
    userId: v.string(),
    categoryId: v.string(),
  },
  handler: async (ctx, args) => {
    return await ctx.db
      .query('budgets')
      .withIndex('by_user_category', (q) =>
        q.eq('userId', args.userId).eq('categoryId', args.categoryId),
      )
      .first();
  },
});

export const create = mutation({
  args: {
    categoryId: v.optional(v.string()),
    amount: v.number(),
    period: v.union(v.literal('weekly'), v.literal('monthly')),
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);
    return await ctx.db.insert('budgets', {
      userId,
      categoryId: args.categoryId,
      amount: args.amount,
      period: args.period,
      createdAt: Date.now(),
    });
  },
});

export const update = mutation({
  args: {
    id: v.id('budgets'),
    amount: v.number(),
    period: v.optional(
      v.union(v.literal('weekly'), v.literal('monthly')),
    ),
  },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);
    const budget = await ctx.db.get(args.id);
    if (!budget || budget.userId !== userId) {
      throw new Error('Budget not found or unauthorized');
    }
    const { id, period, ...rest } = args;
    const updates: Record<string, unknown> = { ...rest };
    if (period !== undefined) {
      updates.period = period;
    }
    await ctx.db.patch(id, updates);
  },
});

export const remove = mutation({
  args: { id: v.id('budgets') },
  handler: async (ctx, args) => {
    const userId = await requireAuth(ctx);
    const budget = await ctx.db.get(args.id);
    if (!budget || budget.userId !== userId) {
      throw new Error('Budget not found or unauthorized');
    }
    await ctx.db.delete(args.id);
  },
});
