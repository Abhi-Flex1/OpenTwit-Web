// OpenTwit-Web design tokens.
//
// Colours are intentionally NOT declared here: the shell uses the HarmonyOS
// system colour resources ($r('sys.color.ohos_id_color_*')) so light/dark
// adaptation, high-contrast modes and future theme changes are handled by the
// system instead of a hand-maintained copy of the palette.
//
// Typography: the app never overrides the font family — HarmonyOS Sans (and
// the user's font-size / bold-text accessibility settings) apply by default.

// The shell pins every native text node to HarmonyOS Sans explicitly instead of
// relying on the default, and the web content is pinned to the same family by
// the injected stylesheet in WebChrome.ets. One family, everywhere.
export const FONT_FAMILY: string = 'HarmonyOS Sans';

// Spacing scale (vp).
export const S2: number = 2;
export const S4: number = 4;
export const S8: number = 8;
export const S12: number = 12;
export const S16: number = 16;
// HarmonyOS content gutter used on phones where a surface needs the platform's
// wider margin rather than the standard 16vp one.
export const S20: number = 20;

// Corner radius used by cards and sheets (vp).
export const RADIUS: number = 16;
// Small radius for in-list surfaces (message bubbles, embedded post cards).
export const RADIUS_SM: number = 8;
// Icon button used inside a list row or the chat composer (vp).
export const TOOL_BUTTON: number = 40;

// Height of a conversation row (48vp avatar plus its vertical breathing room).
export const ROW_HEIGHT: number = 76;

// Loading indicator drawn above the web content (vp).
export const PROGRESS_HEIGHT: number = 2;

// Minimum touch target for the bottom navigation (vp) — HarmonyOS asks for
// 48vp so the bar stays usable with large fonts and for motor-impaired users.
export const TOUCH_TARGET: number = 48;

// Width of the bottom bar (vp).
export const BAR_HEIGHT: number = 56;

// Height of the floating title bar's content row (vp). The bar is translucent
// and the page is inset from inside by this much plus the status bar, so page
// content scrolls underneath it and blurs.
export const HEADER_HEIGHT: number = 56;

// Width of the side navigation rail used on wide (tablet / unfolded
// foldable / 2in1) layouts (vp).
export const RAIL_WIDTH: number = 88;

// Width breakpoint at which the bottom bar turns into a side rail (vp).
export const WIDE_BREAKPOINT: number = 840;
