# SwiftTerm, vendored

- **Upstream:** https://github.com/migueldeicaza/SwiftTerm, tag `v1.11.2` (commit `b1262db5b6bea699a8260a8c66999436c508ca56`), MIT license (`LICENSE`, unchanged).
- **Kept:** `Sources/SwiftTerm` only. **Removed:** `iOS/` and `Documentation.docc/`, plus everything outside `Sources/SwiftTerm` (tests, fuzzer, `termcast`, benchmarks). `Package.swift` is rewritten to build just the library, with `-suppress-warnings`.

## Why vendored, and why 1.11.2

- SwiftTerm 1.12 and later ship a Metal shader as a SwiftPM resource. Building it needs Xcode's separately downloaded "Metal Toolchain", which the Command Line Tools don't have, so `install.sh` would fail on most Macs. Don't upgrade past 1.11.x while that is true.
- 1.11.2 turns font smoothing on for every line it draws, which blurs pixel fonts. The two patches below come from SwiftTerm 1.19 and keep upstream names, so a future upgrade drops them.

## Patches (search for "Retro98 patch")

1. **`fontSmoothing`:** a public `TerminalView.fontSmoothing` (default `true`, as upstream). `AppleTerminalView.swift` passes it to `setShouldSmoothFonts`/`setAllowsFontSmoothing` instead of `true`.
2. **`reservedScrollerWidth`:** when the built-in scroller is hidden, `getEffectiveWidth` and `getOptimalFrameSize` reserve no width for it, so a host can show its own scroll bar.
