# whoop_hrvcv

Lightweight iOS app that shows your WHOOP HRV values (last 7 days) with backend-managed OAuth and token refresh.

## What changed

The app is now user-facing only:
- No client ID/client secret/token fields in iOS UI
- On launch, app fetches HRV automatically
- If WHOOP is not connected yet, app shows a single **Login to WHOOP** button
- Backend stores refresh token and refreshes access token automatically

## Project structure

- `/Users/samridhsharma/whoop_hrvcv/WhoopHRVCVPrototype`: iOS app source
- `/Users/samridhsharma/whoop_hrvcv/backend`: backend service for WHOOP OAuth + refresh + HRV proxy

## Backend setup (required)

1. Open `/Users/samridhsharma/whoop_hrvcv/backend/.env.example` and copy it to `.env`.
2. Fill these values in `/Users/samridhsharma/whoop_hrvcv/backend/.env`:
   - `WHOOP_CLIENT_ID`
   - `WHOOP_CLIENT_SECRET`
   - `WHOOP_REDIRECT_URI` (default: `http://localhost:8787/auth/callback`)
   - `BACKEND_BASE_URL` (default: `http://localhost:8787`)
   - `WHOOP_SCOPE` (use `offline read:recovery`)
3. Start backend:

```bash
cd /Users/samridhsharma/whoop_hrvcv/backend
npm install
npm start
```

Backend endpoints used by app:
- `GET /auth/start` (starts WHOOP login)
- `GET /auth/callback` (stores refresh/access token)
- `GET /hrv?days=7` (returns HRV values)

## iOS app setup

1. In `/Users/samridhsharma/whoop_hrvcv/WhoopHRVCVPrototype/WhoopConfig.plist`, set:
   - `BACKEND_BASE_URL` (default `http://localhost:8787`)
2. Open `/Users/samridhsharma/whoop_hrvcv/WhoopHRVCV.xcodeproj` in Xcode.
3. Run app on simulator/device.

## User flow

1. Open app.
2. If first-time setup, tap **Login to WHOOP** and complete browser auth.
3. Return to app and tap **I Have Logged In, Refresh**.
4. After that, opening the app refreshes HRV automatically.

## Security note

Do not keep real WHOOP secrets in the iOS app bundle. Keep `WHOOP_CLIENT_SECRET` only in backend `.env`.
