import { getAuthConfigProvider } from '@convex-dev/better-auth/auth-config';
import type { AuthConfig } from 'convex/server';

const config: AuthConfig = {
  providers: [getAuthConfigProvider()],
};

export default config;
