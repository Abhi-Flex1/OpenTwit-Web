# Live Setup

Guide for enabling live Twitter login in OpenTwit.

## Create App

No API key needed. OpenTwit uses keyless web endpoints: syndication endpoints plus fxtwitter plus in-app WebView fallback. No developer app or Client ID required.

## Paste Client ID

No API key needed — skip this step. There is no Client ID to copy or paste for the keyless web fetch flow.

## Sign In Steps

1. Open OpenTwit and go to the Login page.
2. Enter your Twitter handle (no API key needed).
3. Tap Sign In to load the timeline via keyless web endpoints (syndication / fxtwitter, with in-app WebView fallback if needed).

## Token Storage

- The Twitter handle is persisted in Preferences `opentwit_auth` under key `twitter_handle`.
- Timeline cache: cached timeline entries expire after 15 minutes.
- Clearing the app data or removing that preference entry signs the user out.
