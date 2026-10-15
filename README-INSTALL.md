# Add DMG releases to marcmend/brew

Copy `.github/workflows/release.yml` and `scripts/create-dmg.sh` to the same paths in the Brew repository.

Commit and push, then tag a release:

```bash
git add .github/workflows/release.yml scripts/create-dmg.sh
git commit -m "ci: package Brew as a DMG and publish releases"
git push
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions builds `build/Brew.app`, creates `dist/Brew-1.0.0-arm64.dmg`, and uploads it to the `v1.0.0` GitHub Release. Manual workflow dispatch produces an Actions artifact without creating a Release.

Note: the current build.sh uses ad-hoc signing, so macOS Gatekeeper may warn/block downloads. For public distribution without those warnings, Apple Developer ID signing and notarization are needed. Current build targets arm64 only. The workflow has not been executed against the repository; validate on GitHub Actions.
