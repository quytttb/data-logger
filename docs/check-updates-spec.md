# Firmware / app update check (backlog spec)

`SettingsController.checkUpdates()` is currently a **stub** that shows an informational toast.

## Open questions (must be decided before implementation)

1. **Update source**
   - GitHub Releases API (`owner/repo`, asset = `.deb` / tarball)?
   - Private firmware URL on customer FTP?
   - OTA endpoint on Central App?

2. **Version compare**
   - Semantic version from `CMakeLists.txt` `project(DataLogger VERSION x.y.z)`?
   - Build date / git commit hash?

3. **UX**
   - Toast only vs. modal with release notes?
   - Auto-check on startup vs. manual button only (Settings → General)?

4. **Offline / embedded**
   - Data Logger runs on field devices — assume no internet unless configured?

## Suggested minimal v1

- Manual **Check for updates** button (already in Settings General tab).
- HTTP GET to configurable URL returning JSON: `{ "version": "2.1.0", "url": "...", "notes": "..." }`.
- Compare with app version; show `AppNotifier` success/info if up to date, warning if newer available (no auto-install).

Until this spec is approved, do not implement network download or install.
