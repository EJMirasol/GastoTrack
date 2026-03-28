import { defineSchema, defineTable } from 'convex/server';
import { v } from 'convex/values';

export default defineSchema({
  categories: defineTable({
    name: v.string(),
    icon: v.string(),
    color: v.string(),
    isDefault: v.boolean(),
    userId: v.optional(v.string()),
  }),

  expenses: defineTable({
    amount: v.number(),
    categoryId: v.string(),
    userId: v.string(),
    groupId: v.optional(v.id('groups')),
    description: v.optional(v.string()),
    date: v.number(),
    type: v.union(v.literal('expense'), v.literal('income')),
    isRecurring: v.boolean(),
    recurringRuleId: v.optional(v.id('recurringRules')),
    createdAt: v.number(),
  })
    .index('by_user', ['userId'])
    .index('by_user_date', ['userId', 'date'])
    .index('by_group', ['groupId']),

  recurringRules: defineTable({
    userId: v.string(),
    amount: v.number(),
    categoryId: v.string(),
    description: v.optional(v.string()),
    frequency: v.union(
      v.literal('daily'),
      v.literal('weekly'),
      v.literal('monthly'),
      v.literal('yearly'),
    ),
    nextDueDate: v.number(),
    isActive: v.boolean(),
    createdAt: v.number(),
  }).index('by_user', ['userId']),

  groups: defineTable({
    name: v.string(),
    createdBy: v.string(),
    members: v.array(v.string()),
    inviteCode: v.string(),
    createdAt: v.number(),
  })
    .index('by_creator', ['createdBy'])
    .index('by_invite_code', ['inviteCode']),

  groupMembers: defineTable({
    groupId: v.id('groups'),
    userId: v.string(),
    joinedAt: v.number(),
  })
    .index('by_group', ['groupId'])
    .index('by_user', ['userId']),

  settlements: defineTable({
    groupId: v.id('groups'),
    fromUserId: v.string(),
    toUserId: v.string(),
    amount: v.number(),
    isSettled: v.boolean(),
    settledAt: v.optional(v.number()),
    createdAt: v.number(),
  }).index('by_group', ['groupId']),

  budgets: defineTable({
    userId: v.string(),
    categoryId: v.optional(v.string()),
    amount: v.number(),
    period: v.union(v.literal('weekly'), v.literal('monthly')),
    createdAt: v.number(),
  })
    .index('by_user', ['userId'])
    .index('by_user_category', ['userId', 'categoryId']),
});
