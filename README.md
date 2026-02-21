# whoop_hrvcv

A lightweight iOS app prototype to fetch WHOOP HRV data, which will be used to compute weekly coefficient of variation (CV).

## What is implemented

The first milestone is complete in `WhoopHRVCVPrototype/`:

- `WhoopHRVCVPrototype/WhoopAPIClient.swift`: Calls WHOOP Developer API v2 `GET /recovery`
- `WhoopHRVCVPrototype/WhoopModels.swift`: Decodes recovery data, including `score.hrv_rmssd_milli`
- `WhoopHRVCVPrototype/WhoopConfig.swift`: Loads WHOOP OAuth config from plist
- `WhoopHRVCVPrototype/HRVViewModel.swift`: Loads config and fetches the last 7 days of HRV samples
- `WhoopHRVCVPrototype/ContentView.swift`: UI showing Client ID/Client Secret and fetching HRV

## WHOOP setup

1. Create a WHOOP developer app and enable scope `read:recovery`.
2. Fill `/Users/samridhsharma/whoop_hrvcv/WhoopHRVCVPrototype/WhoopConfig.plist`:
   - `CLIENT_ID`
   - `CLIENT_SECRET`
   - `REDIRECT_URI`
   - `ACCESS_TOKEN`
3. Tap **Fetch Last 7 Days HRV**.

## API details used

- Base URL: `https://api.prod.whoop.com/developer/v2`
- Endpoint: `GET /recovery`
- Query params:
  - `start` (ISO-8601)
  - `end` (ISO-8601)
  - `limit` (currently `25`)
  - `nextToken` (for pagination)
- HRV field extracted: `score.hrv_rmssd_milli`

## Running this in Xcode

1. Create a new iOS App project in Xcode.
2. Copy all files from `WhoopHRVCVPrototype/` into your app target.
3. Build and run on simulator/device.

## Next milestone

Compute weekly CV from fetched HRV values:

`CV = (standardDeviation(HRV) / mean(HRV)) * 100`
