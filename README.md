# Trireme

Deluge client written with flutter.

<a href="https://f-droid.org/app/org.deluge.trireme"><img src="https://f-droid.org/badge/get-it-on.png" alt="Get it on F-Droid" height="100"></a>

## Getting Started

For help getting started with Flutter, view our online
[documentation](https://flutter.io/).

## Release signing

Android identifies an app by its signing key. An APK signed with a different
key than the installed one cannot be installed over it -- the only way through
is to uninstall first, which deletes the server list and every preference. So
every published build has to be signed with the same key, forever.

The key lives in `android/key.properties`, which is gitignored and absent from
a fresh clone. Without it the `github` flavor falls back to the debug key. That
is fine locally, but a CI runner generates a fresh debug key on every run, so
those APKs can never be upgraded in place and must not be published.

### Creating the key

Once, and then keep it safe -- losing it means no existing install can ever be
upgraded again:

```bash
keytool -genkeypair -v -keystore trireme-release.keystore   -alias trireme -keyalg RSA -keysize 2048 -validity 10000
```

Back up the keystore file and its passwords somewhere durable and private.

### Building a signed release locally

Put the keystore at `android/app/release.keystore` and create
`android/key.properties`:

```properties
storeFile=release.keystore
storePassword=<store password>
keyAlias=trireme
keyPassword=<key password>
```

`storeFile` is resolved relative to `android/app`. Neither file is tracked, and
`android/.gitignore` covers `*.keystore` and `*.jks` so they cannot be committed
by accident.

### Signing in CI

Set four repository secrets:

| Secret | Value |
|---|---|
| `RELEASE_KEYSTORE_BASE64` | the keystore file, base64 encoded |
| `RELEASE_STORE_PASSWORD` | store password |
| `RELEASE_KEY_ALIAS` | key alias |
| `RELEASE_KEY_PASSWORD` | key password |

Encode the keystore with:

```bash
base64 -w0 trireme-release.keystore    # macOS: base64 -i trireme-release.keystore
```

The workflow writes both files before building and deletes them afterwards.
Secrets are not exposed to pull requests from forks, so those builds fall back
to the debug key and are annotated with a warning on the run; they are for
testing only.

Every run prints the certificate the APK actually carries. With the secrets set
that fingerprint must be identical on every build -- if it changes, existing
installs can no longer be upgraded.
