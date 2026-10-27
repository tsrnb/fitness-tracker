# CutTracker

A personal fitness tracker for a fat-loss or muscle-gain phase: diet and macros, training plans with an exercise
library and animations, weight and strength progress, a 14-day calibration, and AI help for logging and insights.
Sign-in is Google only, and each person's data lives in their account.

| Folder | What it is |
|---|---|
| `flutter_app/` | The app (web, Android, iOS). See its README to run it. |
| `infra/` | The AWS backend (CDK): API, database, AI proxy, CDN for exercise clips. See its README to deploy. |
| `scripts/` | `deploy-gh-pages.sh`, which builds the web app and publishes it to GitHub Pages. |

## Environments

Two separate AWS stacks, `CutTracker-dev` and `CutTracker-prod`, each with its own config file in `flutter_app/`
(`secrets.dev.json`, `secrets.prod.json`; git-ignored, see `secrets.example.json`). The live site at
https://tsrnb.github.io/fitness-tracker/ uses prod.

## Publish the web app

```bash
npm run deploy
```

Builds `flutter_app` with `secrets.prod.json` and pushes the result to the `gh-pages` branch. It stops if that file
is missing or points at localhost.

## Sign-in access

While the Google OAuth consent screen is in Testing mode, only emails listed under Google Auth Platform > Audience >
Test users can sign in. Add new testers there first.
