# MyNotch

Personal fork of [boring.notch](https://github.com/TheBoredTeam/boring.notch) (GPL-3.0).
It is maintained independently and is not meant to be merged back upstream.

## Changes compared to upstream

### Fixes
- Album art matches the current track, including streamed Apple Music tracks: empty AppleScript artwork is treated as "none" and the cover is fetched from macOS Now Playing as a fallback.
- The progress slider no longer jumps back after a seek.
- Hover: new setting to not open the notch when the cursor arrives from the menu bar, plus an optional extra delay that only applies in that case.

### Privacy and security
- No network calls for lyrics (Apple Music lyrics are read locally), no telemetry, no auto-update (Sparkle is never started), no `network.server` entitlement.
- The XPC helper only accepts connections from the app.
- Own bundle identifier (`louisvct.mynotch`), so it can live next to the original app.

### New features
- **Timer and Pomodoro** (notch header button): iPhone-style orange countdown, Timer and Pomodoro modes, 4-dot cycle indicator, optional task name, focus and breaks chained automatically (can be turned off), next-phase / cancel / pause buttons, menu bar shortcuts.
- **AI agent alerts**: banners and badges when Claude Code (or any tool) needs your input or has finished; clicking jumps back to the app. Hooks and scripts are in [`integrations/`](integrations), see [docs/AGENT_ALERTS.md](docs/AGENT_ALERTS.md).
- **File conversion on drop**: dropping a file on the shelf offers to convert it to another format (can be disabled).
- **Swipe gesture** to change track (can be disabled).
- **Adaptive open notch size** that follows its content (can be disabled).
- **Artwork cache**: size chosen in Settings > Media (kept in memory as compressed data, capped at 48 MB).

Ideas for later are listed in [IDEAS.md](IDEAS.md).

## Builds and updates

Every push to `main` builds the app on GitHub Actions and publishes a release (`build-N`) with a `.dmg`.
The app is only ad-hoc signed: on first launch, right-click the app and choose **Open**.

There is no in-app updater. To update, run:

```bash
curl -fsSL https://raw.githubusercontent.com/LouisVct/mynotch/main/integrations/update-mynotch.sh | bash
```

The same command is shown, with a copy button, in Settings > About.

## License

GPL-3.0, see [LICENSE](LICENSE). Original work by the boring.notch authors.
