import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const getByUser = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("expenses")
      .withIndex("by_user", (q) => q.eq("userId", args.userId))
      .order("desc")
      .collect();
  },
});

export const getByUserAndMonth = query({
  args: {
    userId: v.id("users"),
    startOfMonth: v.number(),
    endOfMonth: v.number(),
  },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("expenses")
      .withIndex("by_user_date", (q) =>
        q.eq("userId", args.userId).gte("date", args.startOfMonth).lte("date", args.endOfMonth)
      )
      .order("desc")
      .collect();
  },
});

export const getByGroup = query({
  args: { groupId: v.id("groups") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("expenses")
      .withIndex("by_group", (q) => q.eq("groupId", args.groupId))
      .order("desc")
      .collect();
  },
});

export const create = mutation({
  args: {
    amount: v.number(),
    categoryId: v.id("categories"),
    userId: v.id("users"),
    groupId: v.optional(v.id("groups")),
    description: v.optional(v.string()),
    date: v.number(),
    type: v.union(v.literal("expense"), v.literal("income")),
    isRecurring: v.optional(v.boolean()),
    recurringRuleId: v.optional(v.id("recurringRules")),
  },
  handler: async (ctx, args) => {
    return await ctx.db.insert("expenses", {
      amount: args.amount,
      categoryId: args.categoryId,
      userId: args.userId,
      groupId: args.groupId,
      description: args.description,
      date: args.date,
      type: args.type,
      isRecurring: args.isRecurring ?? false,
      recurringRuleId: args.recurringRuleId,
      createdAt: Date.now(),
    });
  },
});

export const update = mutation({
  args: {
    id: v.id("expenses"),
    amount: v.optional(v.number()),
    description: v.optional(v.string()),
    date: v.optional(v.number()),
    categoryId: v.optional(v.id("categories")),
  },
  handler: async (ctx, args) => {
    const { id, ...fields } = args;
    await ctx.db.patch(id, fields);
  },
});

export const remove = mutation({
  args: { id: v.id("expenses") },
  handler: async (ctx, args) => {
    await ctx.db.delete(args.id);
  },
});
