import http from '@ohos.net.http';

export class TweetData {
  userName: string;
  handle: string;
  time: string;
  content: string;
  likes: number;
  reposts: number;
  replies: number;

  constructor(userName: string, handle: string, time: string, content: string, likes: number, reposts: number) {
    this.userName = userName;
    this.handle = handle;
    this.time = time;
    this.content = content;
    this.likes = likes;
    this.reposts = reposts;
    this.replies = 0;
  }
}

class CacheEntry {
  tweets: TweetData[] = [];
  timestamp: number = 0;
}

export class WebTimeline {
  static userAgent: string = 'OpenTwit-Web HarmonyOS WebView';
  private static cache: Record<string, CacheEntry> = {};
  private static CACHE_TTL_MS: number = 15 * 60 * 1000;

  private static normalize(handle: string): string {
    return handle.startsWith('@') ? handle.substring(1) : handle;
  }

  private static isFresh(entry: CacheEntry | undefined): boolean {
    if (!entry) {
      return false;
    }
    return (Date.now() - entry.timestamp) < WebTimeline.CACHE_TTL_MS;
  }

  private static async getJson(url: string): Promise<ESObject | undefined> {
    try {
      let httpRequest = http.createHttp();
      let response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': WebTimeline.userAgent
        }
      });
      if (response && response.responseCode === 200 && response.result) {
        return JSON.parse(response.result as string) as ESObject;
      }
    } catch (err) {
    }
    return undefined;
  }

  static async fetchByHandle(handle: string): Promise<TweetData[]> {
    let name: string = WebTimeline.normalize(handle);
    let key: string = '@' + name;
    let cached: CacheEntry | undefined = WebTimeline.cache[key];
    if (WebTimeline.isFresh(cached)) {
      return (cached as CacheEntry).tweets;
    }
    let tweets: TweetData[] = await WebTimeline.fetchLive(key, name);
    WebTimeline.cache[key] = { tweets: tweets, timestamp: Date.now() } as CacheEntry;
    return tweets;
  }

  private static async fetchLive(key: string, name: string): Promise<TweetData[]> {
    // fxtwitter first: reachable without a key. Syndication second:
    // official Twitter web endpoint for networks where it responds.
    let fxParsed: ESObject | undefined = await WebTimeline.getJson('https://api.fxtwitter.com/' + name);
    if (fxParsed) {
      let fxTweets: TweetData[] = WebTimeline.mapItems(fxParsed, key);
      if (fxTweets.length > 0) {
        return fxTweets;
      }
    }
    let parsed: ESObject | undefined = await WebTimeline.getJson('https://syndication.twitter.com/timeline/profile/' + name);
    if (parsed) {
      return WebTimeline.mapItems(parsed, key);
    }
    return [];
  }

  static async fetchTrends(): Promise<string[]> {
    let parsed: ESObject | undefined = await WebTimeline.getJson('https://syndication.twitter.com/timeline/trends');
    let trends: string[] = WebTimeline.mapTrends(parsed);
    if (trends.length > 0) {
      return trends;
    }
    let fallback: ESObject | undefined = await WebTimeline.getJson('https://api.fxtwitter.com/trends');
    return WebTimeline.mapTrends(fallback);
  }

  static async fetchNotifications(handle: string): Promise<TweetData[]> {
    let name: string = WebTimeline.normalize(handle);
    let parsed: ESObject | undefined = await WebTimeline.getJson('https://syndication.twitter.com/timeline/notifications/' + name);
    if (parsed) {
      let tweets: TweetData[] = WebTimeline.mapItems(parsed, '@' + name);
      if (tweets.length > 0) {
        return tweets;
      }
    }
    let fallback: ESObject | undefined = await WebTimeline.getJson('https://api.fxtwitter.com/' + name + '/notifications');
    if (fallback) {
      return WebTimeline.mapItems(fallback, '@' + name);
    }
    return [];
  }

  static async fetchMessages(handle: string): Promise<TweetData[]> {
    let name: string = WebTimeline.normalize(handle);
    let parsed: ESObject | undefined = await WebTimeline.getJson('https://syndication.twitter.com/timeline/messages/' + name);
    if (parsed) {
      let tweets: TweetData[] = WebTimeline.mapItems(parsed, '@' + name);
      if (tweets.length > 0) {
        return tweets;
      }
    }
    let fallback: ESObject | undefined = await WebTimeline.getJson('https://api.fxtwitter.com/' + name + '/messages');
    if (fallback) {
      return WebTimeline.mapItems(fallback, '@' + name);
    }
    return [];
  }

  private static mapTrends(parsed: ESObject | undefined): string[] {
    if (!parsed) {
      return [];
    }
    try {
      let record: Record<string, ESObject> = parsed as Record<string, ESObject>;
      let items: ESObject[] | undefined = undefined;
      if (record['trends']) {
        items = record['trends'] as ESObject[];
      } else if (record['timeline']) {
        items = record['timeline'] as ESObject[];
      } else if (Array.isArray(parsed)) {
        items = parsed as ESObject[];
      }
      if (!items) {
        return [];
      }
      let trends: string[] = [];
      for (let i: number = 0; i < items.length; i++) {
        let entry: Record<string, ESObject> = items[i] as Record<string, ESObject>;
        if (entry['name']) {
          trends.push(entry['name'] as string);
        } else if (entry['text']) {
          trends.push(entry['text'] as string);
        }
      }
      return trends;
    } catch (err) {
      return [];
    }
  }

  private static mapItems(parsed: ESObject, handle: string): TweetData[] {
    let tweets: TweetData[] = [];
    try {
      let items: ESObject[] = [];
      if (parsed && (parsed as Record<string, ESObject>)['tweets']) {
        items = ((parsed as Record<string, ESObject>)['tweets']) as ESObject[];
      } else if (parsed && (parsed as Record<string, ESObject>)['timeline']) {
        items = ((parsed as Record<string, ESObject>)['timeline']) as ESObject[];
      } else if (Array.isArray(parsed)) {
        items = parsed as ESObject[];
      }
      for (let i: number = 0; i < items.length; i++) {
        let item: ESObject = items[i];
        let record: Record<string, ESObject> = item as Record<string, ESObject>;
        let text: string = '';
        if (record['text']) {
          text = record['text'] as string;
        } else if (record['full_text']) {
          text = record['full_text'] as string;
        } else if (record['content']) {
          text = record['content'] as string;
        } else {
          continue;
        }
        let id: string = record['id_str'] ? (record['id_str'] as string) : (record['id'] ? String(record['id']) : handle + text.length);
        tweets.push(new TweetData(handle, handle, 'now', text, 0, 0));
        void id;
      }
    } catch (err) {
      return [];
    }
    return tweets;
  }
}
