import { HttpError } from '../errors.js';

/** The subset of fetch we use, so tests can swap in a fake GitHub. */
export type Fetch = (url: string, init?: RequestInit) => Promise<Response>;

export interface ContributionDay {
  date: string; // YYYY-MM-DD
  count: number;
}

export type DevicePollResult =
  | { status: 'pending' | 'slow_down' | 'expired' | 'denied' }
  | { status: 'authorized'; accessToken: string };

/** Each contribution (commit, PR, review, issue) is treated as ~10 minutes of coding, capped per day. */
export const MINUTES_PER_CONTRIBUTION = 10;
export const MAX_GITHUB_MINUTES_PER_DAY = 120;

export function minutesForContributions(count: number): number {
  return Math.min(count * MINUTES_PER_CONTRIBUTION, MAX_GITHUB_MINUTES_PER_DAY);
}

export class GitHubClient {
  constructor(
    private readonly fetch: Fetch = globalThis.fetch,
    private readonly clientId?: string,
  ) {}

  get deviceFlowEnabled(): boolean {
    return Boolean(this.clientId);
  }

  private async api<T>(token: string, path: string, init?: RequestInit): Promise<T> {
    const res = await this.fetch(`https://api.github.com${path}`, {
      ...init,
      headers: {
        authorization: `Bearer ${token}`,
        accept: 'application/vnd.github+json',
        'user-agent': 'life-rpg',
        ...(init?.body ? { 'content-type': 'application/json' } : {}),
      },
    });
    if (res.status === 401) throw new HttpError(400, 'GitHub rejected the token. Reconnect GitHub.');
    if (!res.ok) throw new HttpError(502, `GitHub responded ${res.status}`);
    return (await res.json()) as T;
  }

  async viewerLogin(token: string): Promise<string> {
    const user = await this.api<{ login: string }>(token, '/user');
    return user.login;
  }

  /**
   * Daily contribution counts between two instants. Uses the contribution calendar because it is the
   * same number GitHub shows on the profile and includes private work when the token is the user's own.
   */
  async contributions(token: string, from: Date, to: Date): Promise<ContributionDay[]> {
    const query = `query($from: DateTime!, $to: DateTime!) {
      viewer { contributionsCollection(from: $from, to: $to) {
        contributionCalendar { weeks { contributionDays { date contributionCount } } }
      } }
    }`;
    const body = await this.api<{
      data?: { viewer: { contributionsCollection: { contributionCalendar: { weeks: Array<{ contributionDays: Array<{ date: string; contributionCount: number }> }> } } } };
      errors?: Array<{ message: string }>;
    }>(token, '/graphql', {
      method: 'POST',
      body: JSON.stringify({ query, variables: { from: from.toISOString(), to: to.toISOString() } }),
    });
    if (!body.data) throw new HttpError(502, body.errors?.[0]?.message ?? 'GitHub query failed');
    return body.data.viewer.contributionsCollection.contributionCalendar.weeks
      .flatMap((w) => w.contributionDays)
      .map((d) => ({ date: d.date, count: d.contributionCount }));
  }

  private requireClientId(): string {
    if (!this.clientId) throw new HttpError(400, 'GitHub sign-in is not configured on this server');
    return this.clientId;
  }

  /** Step 1 of the OAuth device flow: the app shows userCode and opens verificationUri. */
  async startDeviceFlow() {
    const res = await this.fetch('https://github.com/login/device/code', {
      method: 'POST',
      headers: { accept: 'application/json', 'content-type': 'application/json' },
      body: JSON.stringify({ client_id: this.requireClientId(), scope: 'read:user' }),
    });
    if (!res.ok) throw new HttpError(502, `GitHub responded ${res.status}`);
    const j = (await res.json()) as { device_code: string; user_code: string; verification_uri: string; interval: number; expires_in: number };
    return {
      deviceCode: j.device_code,
      userCode: j.user_code,
      verificationUri: j.verification_uri,
      interval: j.interval,
      expiresIn: j.expires_in,
    };
  }

  /** Step 2: the app polls until the user approves on github.com. */
  async pollDeviceFlow(deviceCode: string): Promise<DevicePollResult> {
    const res = await this.fetch('https://github.com/login/oauth/access_token', {
      method: 'POST',
      headers: { accept: 'application/json', 'content-type': 'application/json' },
      body: JSON.stringify({
        client_id: this.requireClientId(),
        device_code: deviceCode,
        grant_type: 'urn:ietf:params:oauth:grant-type:device_code',
      }),
    });
    if (!res.ok) throw new HttpError(502, `GitHub responded ${res.status}`);
    const j = (await res.json()) as { access_token?: string; error?: string };
    if (j.access_token) return { status: 'authorized', accessToken: j.access_token };
    switch (j.error) {
      case 'authorization_pending':
        return { status: 'pending' };
      case 'slow_down':
        return { status: 'slow_down' };
      case 'access_denied':
        return { status: 'denied' };
      default:
        return { status: 'expired' };
    }
  }
}
