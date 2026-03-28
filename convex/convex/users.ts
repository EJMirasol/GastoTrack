import { mutation } from './_generated/server';
import { v } from 'convex/values';

export const updateSubscription = mutation({
  args: {
    id: v.string(),
    status: v.union(v.literal('free'), v.literal('pro')),
  },
  handler: async (ctx, args) => {
    (ctx.db.patch as any)(args.id, {
      subscriptionStatus: args.status,
    });
  },
});
