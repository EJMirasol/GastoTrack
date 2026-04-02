import { createClient, type GenericCtx } from '@convex-dev/better-auth';
import { convex, crossDomain } from '@convex-dev/better-auth/plugins';
import { components } from './_generated/api';
import { DataModel } from './_generated/dataModel';
import { query, mutation } from './_generated/server';
import { betterAuth } from 'better-auth';
import { v } from 'convex/values';
import authConfig from './auth.config';

const siteUrl = process.env.SITE_URL!;

export const authComponent = createClient<DataModel>(components.betterAuth);

export const createAuth = (ctx: GenericCtx<DataModel>) => {
  return betterAuth({
    baseURL: siteUrl,
    trustedOrigins: [siteUrl],
    database: authComponent.adapter(ctx),
    emailAndPassword: {
      enabled: true,
      requireEmailVerification: false,
      minPasswordLength: 8,
    },
    plugins: [
      crossDomain({ siteUrl }),
      convex({ authConfig }),
    ],
  });
};

export const getCurrentUser = query({
  args: {},
  handler: async (ctx) => {
    return authComponent.getAuthUser(ctx);
  },
});

export const getUserProfile = query({
  args: {},
  handler: async (ctx) => {
    const user = await authComponent.getAuthUser(ctx);
    if (!user) {
      return null;
    }
    return {
      id: user._id,
      email: user.email,
      name: user.name,
      image: user.image,
      emailVerified: user.emailVerified,
      subscriptionStatus:
        (user as Record<string, unknown>).subscriptionStatus ?? 'free',
      createdAt: user._creationTime,
    };
  },
});

export const updateProfile = mutation({
  args: {
    name: v.optional(v.string()),
    email: v.optional(v.string()),
    image: v.optional(v.string()),
    subscriptionStatus: v.optional(
      v.union(v.literal('free'), v.literal('pro')),
    ),
  },
  handler: async (ctx, args) => {
    const user = await authComponent.getAuthUser(ctx);
    if (!user) {
      throw new Error('Not authenticated');
    }
    await ctx.db.patch(user._id as any, args);
  },
});
