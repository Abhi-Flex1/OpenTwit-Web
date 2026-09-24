// Shared native models: every surface reads its data from the page session and
// shapes it into these small closed types. Nothing here invents content — an
// empty or failed read is a state, not a placeholder row.

export interface NativePost {
  id: string;
  name: string;
  handle: string;
  avatar: string;
  text: string;
  at: number;
  time: string;
  likes: number;
  reposts: number;
  replies: number;
  liked: boolean;
  reposted: boolean;
  bookmarked: boolean;
  media: string;
  mediaWidth: number;
  mediaHeight: number;
  mediaType: string;
}

export interface NativeNotificationItem {
  id: string;
  targetId: string;
  kind: string;
  name: string;
  handle: string;
  avatar: string;
  text: string;
  at: number;
  time: string;
}

export interface NativeProfileUser {
  name: string;
  handle: string;
  avatar: string;
  banner: string;
  bio: string;
  location: string;
  followers: number;
  following: number;
  posts: number;
  at: number;
}

export interface NativeTrend {
  name: string;
  posts: string;
}

export interface BridgePost {
  id: string;
  name: string;
  handle: string;
  avatar: string;
  text: string;
  at: number;
  likes: number;
  reposts: number;
  replies: number;
  liked: boolean;
  reposted: boolean;
  bookmarked: boolean;
  media: string;
  mediaWidth: number;
  mediaHeight: number;
  mediaType: string;
}

export interface BridgeTimeline {
  state: string;
  posts?: BridgePost[];
  next?: string;
}

export interface BridgeStateOnly {
  state: string;
  next?: string;
}

export function relativeTime(at: number): string {
  if (!at || at <= 0) {
    return '';
  }
  const seconds: number = Math.floor((Date.now() - at) / 1000);
  if (seconds < 60) {
    return 'now';
  }
  const minutes: number = Math.floor(seconds / 60);
  if (minutes < 60) {
    return minutes.toString() + 'm';
  }
  const hours: number = Math.floor(minutes / 60);
  if (hours < 24) {
    return hours.toString() + 'h';
  }
  const days: number = Math.floor(hours / 24);
  if (days < 7) {
    return days.toString() + 'd';
  }
  const date: Date = new Date(at);
  return (date.getMonth() + 1).toString() + '/' + date.getDate().toString();
}

export function formatCount(n: number): string {
  if (!n || n <= 0) {
    return '';
  }
  if (n < 1000) {
    return n.toString();
  }
  if (n < 1000000) {
    const k: number = n / 1000;
    const rounded: number = Math.round(k * 10) / 10;
    return rounded.toString() + 'K';
  }
  const m: number = n / 1000000;
  const rm: number = Math.round(m * 10) / 10;
  return rm.toString() + 'M';
}

export function stateOf(json: string): string {
  if (!json || json === '') {
    return 'loading';
  }
  try {
    const payload = JSON.parse(json) as Record<string, Object>;
    const state = payload['state'] as string;
    if (!state || state === '') {
      return 'error';
    }
    return state;
  } catch (err) {
    return 'error';
  }
}

export function parsePosts(json: string): NativePost[] {
  if (!json || json === '') {
    return [];
  }
  try {
    const payload = JSON.parse(json) as BridgeTimeline;
    if (!payload || payload.state !== 'ok' || !payload.posts) {
      return [];
    }
    const out: NativePost[] = [];
    const src: BridgePost[] = payload.posts;
    for (let i: number = 0; i < src.length; i++) {
      const p: BridgePost = src[i];
      if (!p || !p.id) {
        continue;
      }
      out.push({
        id: p.id,
        name: p.name ?? '',
        handle: p.handle ?? '',
        avatar: p.avatar ?? '',
        text: p.text ?? '',
        at: p.at ?? 0,
        time: relativeTime(p.at ?? 0),
        likes: p.likes ?? 0,
        reposts: p.reposts ?? 0,
        replies: p.replies ?? 0,
        liked: p.liked === true,
        reposted: p.reposted === true,
        bookmarked: p.bookmarked === true,
        media: p.media ?? '',
        mediaWidth: p.mediaWidth ?? 0,
        mediaHeight: p.mediaHeight ?? 0,
        mediaType: p.mediaType ?? ''
      });
    }
    return out;
  } catch (err) {
    return [];
  }
}

export function nextCursorOf(json: string): string {
  if (!json || json === '') {
    return '';
  }
  try {
    const payload = JSON.parse(json) as BridgeStateOnly;
    if (payload && payload.next) {
      return payload.next;
    }
    return '';
  } catch (err) {
    return '';
  }
}
