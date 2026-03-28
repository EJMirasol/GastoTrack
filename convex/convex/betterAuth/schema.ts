import { defineTable } from 'convex/server';
import { v } from 'convex/values';

export default defineTable({
  subscriptionStatus: v.union(v.literal('free'), v.literal('pro')),
});
