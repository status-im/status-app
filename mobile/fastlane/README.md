# iOS Fastlane Configuration

iOS builds use **fastlane** with **match** for code signing management. This provides:
- Automatic certificate and profile management
- Separate signing for PR vs release builds

## Bundle Identifiers

| Build Type | Bundle ID              | Fastlane Lane |
|------------|------------------------|---------------|
| PR builds  | `app.status.mobile.pr` | `pr`          |
| Release    | `app.status.mobile`    | `release`     |

The share extension embedded in `PlugIns/` is a nested bundle with its own
identifier, `<host id>.ShareExtension`, and is re-signed with its own profile.
Its App IDs (`app.status.mobile.ShareExtension`, `app.status.mobile.pr.ShareExtension`)
need the App Groups capability with `group.app.status.mobile`; match creates
their profiles like the host's (they are listed in `Matchfile`). Set
`FLAG_SHARE_EXTENSION_ENABLED=0` to build without the extension.

## Certificate Types

| Build Type | Certificate Type   | Match Type  | Purpose                       |
|------------|--------------------|-------------|-------------------------------|
| PR builds  | Apple Distribution | `adhoc`     | Testing on registered devices |
| Release    | Apple Distribution | `appstore`  | App Store / TestFlight        |

## Fastlane Files

| File        | Purpose                                      |
|-------------|----------------------------------------------|
| `Fastfile`  | Defines signing lanes (`pr`, `release`)      |
| `Matchfile` | Configures match for certificate management  |
| `Appfile`   | App identifiers and team configuration       |
| `Gemfile`   | Ruby dependencies                            |

## Available Actions

### ios pr

```sh
[bundle exec] fastlane ios pr
```

Sign and package iOS app for PRs

### ios release

```sh
[bundle exec] fastlane ios release
```

Sign and package iOS app for release

## Local Development

To run `fastlane` locally for testing:

```bash
cd mobile/fastlane
nix --extra-experimental-features 'nix-command flakes' develop
bundle install

# Run a specific lane
bundle exec fastlane ios pr
bundle exec fastlane ios release
```

## Revoking/Rotating Certificates

If a certificate is compromised or revoked:

```bash
cd mobile/fastlane

# Nuke existing certificates (warning!! watch what you nuke)
bundle exec fastlane match nuke development
bundle exec fastlane match nuke distribution

# Regenerate (the extension identifiers are covered by the Matchfile defaults)
bundle exec fastlane match adhoc
bundle exec fastlane match appstore
```
