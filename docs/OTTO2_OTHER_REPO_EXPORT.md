# Export Trick — Other Repo (Abhi-Flex1/OpenTwit)

Source repo: Abhi-Flex1/OpenTwit (Open source X/Twitter adaptation for HarmonyOS Devices).
Method: `gh repo view Abhi-Flex1/OpenTwit` (symbol README) to dump README;
`gh api repos/Abhi-Flex1/OpenTwit/commits` (symbol message) to list recent commit messages;
`git log --all --oneline --grep=export -i/--grep=Emulator/--grep=country/--grep=region/--grep=vendorCountry` across commits.

## Exact export command (full line quoted, README.md lines 58-60)

```bash
export PATH="$HOME/Developer/command-line-tools/bin:/opt/homebrew/opt/openjdk@17/bin:$HOME/Developer/command-line-tools/tool/node/bin:$PATH"
export DEVECO_SDK_HOME="$HOME/Developer/command-line-tools/sdk"
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
```

Primary full export line (build env trick):
`export PATH="$HOME/Developer/command-line-tools/bin:/opt/homebrew/opt/openjdk@17/bin:$HOME/Developer/command-line-tools/tool/node/bin:$PATH"`

## Source commit

- Introduced in: `e87a9ee` — "Port X/Twitter to HarmonyOS 6.1 (OpenTwit 1.0.0)" (2026-09-11), which added README.md with the Build `export` block.
- HEAD at read time: `77bbd19` — "Apache-2.0 licensing, README gallery, screenshots" (2026-09-11).
- Recent commit messages (`gh api .../commits`, symbol message): "Apache-2.0 licensing, README gallery, screenshots" / "Remove embedded X Client ID from sources" / "Port X/Twitter to HarmonyOS 6.1 (OpenTwit 1.0.0)" / "Initial commit" — none contains export/Emulator/country/region/vendorCountry; the trick lives in README file content, not in a commit message.
- Local `git log --grep` for symbols export/Emulator/country/region/vendorCountry: zero hits (only 2 local commits).

## README lines (Build section, ## Build)

> Requirements: HarmonyOS Command Line Tools 6.1.1 (or DevEco Studio) with the
> HarmonyOS 6.1.1 SDK, JDK 17, and `~/.npmrc` containing `@ohos:registry=https://repo.harmonyos.com/npm/`.
> ```bash
> export PATH="$HOME/Developer/command-line-tools/bin:/opt/homebrew/opt/openjdk@17/bin:$HOME/Developer/command-line-tools/tool/node/bin:$PATH"
> export DEVECO_SDK_HOME="$HOME/Developer/command-line-tools/sdk"
> export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
> ohpm install
> hvigorw assembleApp
> ```

Note: other repo has no `vendorCountry`/`country.region.xml` emulator region-bypass content; that forensics (Emulator binary `vendorCountry`, `GetUpdatedCountryCode`, `country.region.xml`) lives in this repo's docs (BYPASS_FORENSICS.md etc.), not in Abhi-Flex1/OpenTwit.
