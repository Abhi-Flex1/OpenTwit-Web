import { WebTimeline } from "@bundle:com.example.opentwit/entry/ets/services/WebTimeline";
import type { TweetData } from "@bundle:com.example.opentwit/entry/ets/services/WebTimeline";
export class LiveFeed {
    static async load(handle: string): Promise<TweetData[]> {
        try {
            return await WebTimeline.fetchByHandle(handle);
        }
        catch (err) {
            return [];
        }
    }
}
