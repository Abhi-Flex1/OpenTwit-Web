import http from "@ohos:net.http";
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
    private static async getJson(url: string): Promise<any | undefined> {
        try {
            let httpRequest = http.createHttp();
            let response = await httpRequest.request(url, {
                method: http.RequestMethod.GET,
                header: {
                    'User-Agent': WebTimeline.userAgent
                }
            });
            if (response && response.responseCode === 200 && response.result) {
                return JSON.parse(response.result as string) as any;
            }
        }
        catch (err) {
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
        let fxParsed: any | undefined = await WebTimeline.getJson('https://api.fxtwitter.com/' + name);
        if (fxParsed) {
            let fxTweets: TweetData[] = WebTimeline.mapItems(fxParsed, key);
            if (fxTweets.length > 0) {
                return fxTweets;
            }
        }
        let parsed: any | undefined = await WebTimeline.getJson('https://syndication.twitter.com/timeline/profile/' + name);
        if (parsed) {
            return WebTimeline.mapItems(parsed, key);
        }
        return [];
    }
    static async fetchTrends(): Promise<string[]> {
        let parsed: any | undefined = await WebTimeline.getJson('https://syndication.twitter.com/timeline/trends');
        let trends: string[] = WebTimeline.mapTrends(parsed);
        if (trends.length > 0) {
            return trends;
        }
        let fallback: any | undefined = await WebTimeline.getJson('https://api.fxtwitter.com/trends');
        return WebTimeline.mapTrends(fallback);
    }
    static async fetchNotifications(handle: string): Promise<TweetData[]> {
        let name: string = WebTimeline.normalize(handle);
        let parsed: any | undefined = await WebTimeline.getJson('https://syndication.twitter.com/timeline/notifications/' + name);
        if (parsed) {
            let tweets: TweetData[] = WebTimeline.mapItems(parsed, '@' + name);
            if (tweets.length > 0) {
                return tweets;
            }
        }
        let fallback: any | undefined = await WebTimeline.getJson('https://api.fxtwitter.com/' + name + '/notifications');
        if (fallback) {
            return WebTimeline.mapItems(fallback, '@' + name);
        }
        return [];
    }
    static async fetchMessages(handle: string): Promise<TweetData[]> {
        let name: string = WebTimeline.normalize(handle);
        let parsed: any | undefined = await WebTimeline.getJson('https://syndication.twitter.com/timeline/messages/' + name);
        if (parsed) {
            let tweets: TweetData[] = WebTimeline.mapItems(parsed, '@' + name);
            if (tweets.length > 0) {
                return tweets;
            }
        }
        let fallback: any | undefined = await WebTimeline.getJson('https://api.fxtwitter.com/' + name + '/messages');
        if (fallback) {
            return WebTimeline.mapItems(fallback, '@' + name);
        }
        return [];
    }
    private static mapTrends(parsed: any | undefined): string[] {
        if (!parsed) {
            return [];
        }
        try {
            let record: Record<string, any> = parsed as Record<string, any>;
            let items: any[] | undefined = undefined;
            if (record['trends']) {
                items = record['trends'] as any[];
            }
            else if (record['timeline']) {
                items = record['timeline'] as any[];
            }
            else if (Array.isArray(parsed)) {
                items = parsed as any[];
            }
            if (!items) {
                return [];
            }
            let trends: string[] = [];
            for (let i: number = 0; i < items.length; i++) {
                let entry: Record<string, any> = items[i] as Record<string, any>;
                if (entry['name']) {
                    trends.push(entry['name'] as string);
                }
                else if (entry['text']) {
                    trends.push(entry['text'] as string);
                }
            }
            return trends;
        }
        catch (err) {
            return [];
        }
    }
    private static mapItems(parsed: any, handle: string): TweetData[] {
        let tweets: TweetData[] = [];
        try {
            let items: any[] = [];
            if (parsed && (parsed as Record<string, any>)['tweets']) {
                items = ((parsed as Record<string, any>)['tweets']) as any[];
            }
            else if (parsed && (parsed as Record<string, any>)['timeline']) {
                items = ((parsed as Record<string, any>)['timeline']) as any[];
            }
            else if (Array.isArray(parsed)) {
                items = parsed as any[];
            }
            for (let i: number = 0; i < items.length; i++) {
                let item: any = items[i];
                let record: Record<string, any> = item as Record<string, any>;
                let text: string = '';
                if (record['text']) {
                    text = record['text'] as string;
                }
                else if (record['full_text']) {
                    text = record['full_text'] as string;
                }
                else if (record['content']) {
                    text = record['content'] as string;
                }
                else {
                    continue;
                }
                let id: string = record['id_str'] ? (record['id_str'] as string) : (record['id'] ? String(record['id']) : handle + text.length);
                tweets.push(new TweetData(handle, handle, 'now', text, 0, 0));
                void id;
            }
        }
        catch (err) {
            return [];
        }
        return tweets;
    }
}
