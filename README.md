# MyNotch

Personal fork of [boring.notch](https://github.com/TheBoredTeam/boring.notch) (GPL-3.0).

## Changes compared to upstream

- Album art stays in sync with the current track (diff updates keep the artwork, stale decodes are ignored).
- New setting: don't open the notch when the cursor arrives from the menu bar.
- No network calls for lyrics (Apple Music lyrics are read locally), no auto-update, no `network.server` entitlement.
- XPC helper only accepts connections from the app.
- Own bundle identifier (`louisvct.mynotch`), so it can live next to the original app.

## Builds

Every push to `main` builds the app on GitHub Actions and publishes a release with a `.dmg`.
The app is only ad-hoc signed: on first launch, right-click the app and choose **Open**.

## License

GPL-3.0, see [LICENSE](LICENSE). Original work by the boring.notch authors.
