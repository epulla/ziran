---
name: release
description: Cut a new Ziran release on GitHub - recommend a semver bump (e.g. 0.1.0 -> 0.1.1) from commits since the last tag, let the user choose the version, bump Resources/Info.plist, tag vX.Y.Z and let the GitHub release workflow build and publish Ziran-X.Y.Z.zip. Creates .github/workflows/release.yml first if it is missing. Use when the user asks to release, ship, publish, cut a version, bump the version, or tag Ziran.
---

# Release

Version source of truth: `CFBundleShortVersionString` in `Resources/Info.plist`. Tags are `vX.Y.Z`. Pushing a tag runs `.github/workflows/release.yml`, which tests, builds a universal (`arm64 x86_64`) ad-hoc signed `Ziran.app`, zips it as `Ziran-X.Y.Z.zip`, and publishes a GitHub release with generated notes.

Stop and report on any failed step. Never force-push, move, or delete an existing tag, and never `git reset`, `git stash`, or `git clean`.

## 1. Preconditions

1. `git status --short` is empty, current branch is `main`, and `git pull --ff-only` succeeds. Otherwise stop and tell the user.
2. `gh auth status` succeeds.
3. `make lint && make test` pass.

## 2. Release workflow

If `.github/workflows/release.yml` is missing on `main`:

1. Copy `assets/release.yml` (next to this file) to `.github/workflows/release.yml`.
2. Commit `ci: add release workflow` and push it to `main` before tagging. The workflow must exist on the tagged commit.

If it exists, leave it unchanged.

## 3. Choose the version

1. Current version: `plutil -extract CFBundleShortVersionString raw Resources/Info.plist`.
2. Last tag: `git describe --tags --abbrev=0 --match 'v*'`. If there is none, this is the first release.
3. Commits since the last tag (all commits if none): `git log --oneline <tag>..HEAD`. If there are none since the last tag, stop: nothing to release.
4. Recommend a bump from Conventional Commit subjects:
   - Version < 1.0.0: breaking change (`!:` or `BREAKING CHANGE`) -> minor; anything else -> patch.
   - Version >= 1.0.0: breaking -> major; any `feat:` -> minor; anything else -> patch.
   - First release (no tag): recommend releasing the current Info.plist version unchanged.
5. Ask the user with the question tool. Put the recommendation first, labelled `(Recommended)`, with a one-line reason (e.g. "3 feat, 2 fix since v0.1.0"). Also offer the other bumps (patch, minor, major) as computed versions, and allow a custom answer.
6. Validate the answer: matches `^[0-9]+\.[0-9]+\.[0-9]+$`, is greater than the last tag (first release: not lower than the current Info.plist version), and `git rev-parse -q --verify refs/tags/v<version>` fails. Otherwise ask again.
7. Before changing anything, show the plan (version, whether Info.plist changes, commit + tag to be pushed to `main`) and get an explicit yes.

## 4. Bump, tag, push

If the chosen version differs from Info.plist:

```sh
plutil -replace CFBundleShortVersionString -string "$VERSION" Resources/Info.plist
plutil -replace CFBundleVersion -string "$(( $(plutil -extract CFBundleVersion raw Resources/Info.plist) + 1 ))" Resources/Info.plist
git add Resources/Info.plist
git commit -m "chore: release v$VERSION"
git push origin main
```

Then tag and push the tag:

```sh
git tag -a "v$VERSION" -m "Ziran $VERSION"
git push origin "v$VERSION"
```

## 5. Verify

1. `gh run list --workflow release.yml --limit 1`, then `gh run watch <id> --exit-status`.
2. `gh release view "v$VERSION" --json url,assets -q '.url, .assets[].name'` shows `Ziran-$VERSION.zip`.
3. If the run fails: report the failing step from `gh run view <id> --log-failed`. Don't delete the tag; fix forward with a new patch version.

Report: version, tag, release URL, asset name. Remind the user that the app is ad-hoc signed: after downloading, macOS Gatekeeper requires right-click -> Open (or `xattr -dr com.apple.quarantine Ziran.app`), and Accessibility permission must be granted again.
