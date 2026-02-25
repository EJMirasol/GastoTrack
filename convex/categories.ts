import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const getAll = query({
  handler: async (ctx) => {
    return await ctx.db
      .query("categories")
      .filter((q) => q.eq(q.field("isDefault"), true))
      .collect();
  },
});

export const getByUser = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const defaultCategories = await ctx.db
      .query("categories")
      .filter((q) => q.eq(q.field("isDefault"), true))
      .collect();

    const userCategories = await ctx.db
      .query("categories")
      .filter((q) => q.eq(q.field("userId"), args.userId))
      .collect();

    return [...defaultCategories, ...userCategories];
  },
});

export const create = mutation({
  args: {
    name: v.string(),
    icon: v.string(),
    color: v.string(),
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    return await ctx.db.insert("categories", {
      name: args.name,
      icon: args.icon,
      color: args.color,
      isDefault: false,
      userId: args.userId,
    });
  },
});

export const remove = mutation({
  args: { id: v.id("categories") },
  handler: async (ctx, args) => {
    await ctx.db.delete(args.id);
  },
});
