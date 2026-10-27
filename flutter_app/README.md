# CutTracker app

Flutter app for web, Android and iOS. Data is loaded from the AWS API after Google sign-in; nothing is stored
only on the device.

## Run

Create two config files here (both git-ignored) from `secrets.example.json`: `secrets.dev.json` for the dev
stack and `secrets.prod.json` for prod. Then, in VS Code, pick a launch config:

- **cuttracker-dev**: dev backend. On Chrome it runs on port 8080, the only localhost origin Google and the dev API allow.
- **cuttracker-prod**: prod backend. Real users' data. The prod API only accepts browser requests from
  `https://tsrnb.github.io`, so run this one on a phone or emulator.

From a terminal:

```bash
flutter pub get
flutter run -d chrome --web-port 8080 --dart-define-from-file=secrets.dev.json
```

| Key | Meaning |
|---|---|
| `API_URL` | The HTTP API for accounts, profiles and data |
| `AI_URL` | The AI proxy |
| `CDN_URL` | CloudFront URL for exercise clips (none are bundled in the app) |
| `GOOGLE_WEB_CLIENT_ID` | The Google Web OAuth client ID; Android sign-in also needs its Android client |

## Android sign-in

Android needs an Android OAuth client in the same Google Cloud project with package name
`com.cuttracker.cuttracker` and the SHA-1 of the key that signs the build. `ApiException: 10` means they don't match.

## Tests

```bash
flutter test
```

## Publish

From the repo root: `npm run deploy` (web, to GitHub Pages).
