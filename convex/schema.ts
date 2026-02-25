import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  auth: defineTable({
    userId: v.id("users"),
    tokenIdentifier: v.string(),
    provider: v.string(),
    createdAt: v.number(),
  }).index("by_token", ["tokenIdentifier"]),

  users: defineTable({
    email: v.string(),
    name: v.optional(v.string()),
    subscriptionStatus: v.union(v.literal("free"), v.literal("pro")),
    createdAt: v.number(),
  }).index("by_email", ["email"]),

  categories: defineTable({
    name: v.string(),
    icon: v.string(),
    color: v.string(),
    isDefault: v.boolean(),
    userId: v.optional(v.id("users")),
  }),

  expenses: defineTable({
    amount: v.number(),
    categoryId: v.id("categories"),
    userId: v.id("users"),
    groupId: v.optional(v.id("groups")),
    description: v.optional(v.string()),
    date: v.number(),
    type: v.union(v.literal("expense"), v.literal("income")),
    isRecurring: v.boolean(),
    recurringRuleId: v.optional(v.id("recurringRules")),
    createdAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_user_date", ["userId", "date"])
    .index("by_group", ["groupId"])
    .index("by_category", ["categoryId"]),

  recurringRules: defineTable({
    userId: v.id("users"),
    amount: v.number(),
    categoryId: v.id("categories"),
    description: v.optional(v.string()),
    frequency: v.union(
      v.literal("daily"),
      v.literal("weekly"),
      v.literal("monthly"),
      v.literal("yearly")
    ),
    nextDueDate: v.number(),
    isActive: v.boolean(),
    createdAt: v.number(),
  }).index("by_user", ["userId"]),

  groups: defineTable({
    name: v.string(),
    createdBy: v.id("users"),
    members: v.array(v.id("users")),
    inviteCode: v.string(),
    createdAt: v.number(),
  })
    .index("by_creator", ["createdBy"])
    .index("by_invite_code", ["inviteCode"]),

  groupMembers: defineTable({
    groupId: v.id("groups"),
    userId: v.id("users"),
    joinedAt: v.number(),
  })
    .index("by_group", ["groupId"])
    .index("by_user", ["userId"]),

  settlements: defineTable({
    groupId: v.id("groups"),
    fromUserId: v.id("users"),
    toUserId: v.id("users"),
    amount: v.number(),
    isSettled: v.boolean(),
    settledAt: v.optional(v.number()),
    createdAt: v.number(),
  }).index("by_group", ["groupId"]),

  budgets: defineTable({
    userId: v.id("users"),
    categoryId: v.optional(v.id("categories")),
    amount: v.number(),
    period: v.union(v.literal("weekly"), v.literal("monthly")),
    createdAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_user_category", ["userId", "categoryId"]),
});
