# Neu Onboarding — REST API contract

This document specifies the endpoints the **splash → onboarding** flow calls.
Today they are served by an in-app mock (`lib/core/network/mock_api_interceptor.dart`);
a real backend should implement the same shapes.

## Going live

In `lib/core/network/dio_client.dart`:

```dart
const bool kUseMockApi = false;                 // stop serving canned responses
const String kApiBaseUrl = 'https://<real-host>/v1';
```

Nothing else in the app changes. All requests go through a single `Dio`
(`dioProvider`) that already attaches `Authorization: Bearer <token>` (from
`SharedPreferences['neu_token']`) once the user has signed in.

- Base URL: `kApiBaseUrl`
- Content type: `application/json`
- Auth: `Authorization: Bearer <token>` on every call after signup/login.
- Success: HTTP `2xx` with a JSON object body. Non-2xx should carry
  `{ "error": { "code": "...", "message": "..." } }`.

---

## Auth

### POST /auth/referral/verify
Verify a care-team referral code (no auth yet).

Request:
```json
{ "code": "NEU-7F2A" }
```
Response `200`:
```json
{ "valid": true, "memberName": "Harry" }
```
`valid:false` → the client shows "code not recognised".

### POST /auth/signup
Create the account after the referral is verified.

Request:
```json
{ "email": "user@example.com", "password": "•••••••", "referralCode": "NEU-7F2A" }
```
Response `201`:
```json
{ "userId": "usr_...", "token": "jwt...", "email": "user@example.com", "gender": "female" }
```
`gender` (`female` / `male` / …) is persisted by the client (`neu_gender`) and
drives the dynamic onboarding step count (the menstrual-cycle step is female-only).

### POST /auth/login
Request:
```json
{ "email": "user@example.com", "password": "•••••••" }
```
Response `200`:
```json
{ "userId": "usr_...", "token": "jwt...", "email": "user@example.com", "gender": "female" }
```

---

## Onboarding

All onboarding endpoints require the bearer token.

### GET /onboarding
Full snapshot used to render the flow and to **resume / go back** — the client
re-hydrates every field from here.

Response `200`:
```json
{
  "profile": {
    "fullName": "William Harry",
    "dateOfBirth": "1974-03-14",
    "gender": "female",
    "primaryDiagnosis": "MASLD",
    "diagnosedDate": "2025-01",
    "otherConditions": "Metformin 500mg",
    "currentMedications": ""
  },
  "draft": {
    "motivations": ["insulin_resistance"],
    "supportTypes": ["accountability", "tracking"],
    "activityLevel": "moderate",
    "eatingRhythm": "three_meals",
    "sleepHours": 7,
    "dietaryPrefs": ["vegetarian", "mediterranean"],
    "menstrualCycle": "perimenopause",
    "symptoms": ["fatigue", "bloating"],
    "feeling": { "sleep": 0.5, "energy": 0.5, "stress": 0.5, "mood": 0.5 },
    "note": "",
    "connectChoice": "connected",
    "connectedSources": ["Dexcom", "Withings"],
    "firstAction": "short_walk"
  }
}
```

### PATCH /profile
Persist an inline edit on the Verify-your-information step. Send only the
changed fields.

Request (example):
```json
{ "fullName": "William H. Harry" }
```
Response `200`: the full updated `profile` object (same shape as above).

### PATCH /onboarding
Persist a step's answers (called on every "Save & next"). Send the partial draft
under `answers`; server merges and returns the full draft.

Request:
```json
{ "answers": { "activityLevel": "active", "sleepHours": 8 } }
```
Response `200`: the full merged `draft` object.

### POST /onboarding/complete
Finalize onboarding and return the welcome payload.

Response `200`:
```json
{
  "coachName": "Maya",
  "userName": "William",
  "whatHappensNext": [
    "3–4 days of quiet observation as your data comes in.",
    "A nurse calls you on day 5 to review what we've seen.",
    "Then we build your first treatment plan together."
  ]
}
```

---

## Enumerations (draft field values)

| Field | Allowed values |
| --- | --- |
| `motivations[]` | `recently_diagnosed`, `insulin_resistance`, `family_history`, `doctor_metabolic`, `figuring_out`, `other` |
| `supportTypes[]` | `accountability`, `education`, `hands_on`, `tracking`, `other` |
| `activityLevel` | `low`, `moderate`, `active` |
| `eatingRhythm` | `three_meals`, `grazer`, `intermittent` |
| `dietaryPrefs[]` | `low_carb`, `vegetarian`, `gluten_free`, `mediterranean`, `vegan`, `dairy_free` |
| `menstrualCycle` | `regular`, `irregular`, `perimenopause`, `post_menopause`, `other` (female profiles only) |
| `symptoms[]` | `fatigue`, `poor_sleep`, `hot_flashes`, `bloating`, `mood_shifts`, `brain_fog`, `sugar_cravings`, `none` |
| `feeling.*` | float `0.0`–`1.0` |
| `sleepHours` | int `0`–`14` |
| `connectChoice` | `connected`, `later` |
| `connectedSources[]` | free-form source names read from Health Connect / HealthKit on device (e.g. `Dexcom`, `Withings`) |
| `firstAction` | `short_walk`, `masld_lesson`, `water` |

## Gender & the dynamic step count

`gender` (`female` / `male` / …) determines how many onboarding steps show:

- `female` → **10 steps** (the menstrual-cycle step is included),
- otherwise → **9 steps** (it is skipped).

The value must be returned by **both** `/auth/signup` and `/auth/login` (so the
client knows it before onboarding) and must match `profile.gender` in
`GET /onboarding`. The client persists the auth `gender` to `neu_gender` and
treats it as **authoritative** for the step count, falling back to
`profile.gender` from `GET /onboarding` only when `neu_gender` is unset. The
menstrual-cycle step's `menstrualCycle` field is sent only for female members.

## Client-persisted state (SharedPreferences)

Set by the client from API responses; used by the splash router.

| Key | Set from | Purpose |
| --- | --- | --- |
| `neu_token` | signup / login `token` | bearer auth on all onboarding calls |
| `neu_email` | signup / login `email` | routing / display |
| `neu_gender` | signup / login `gender` | dynamic step count (see above) |
| `neu_onboarding_complete` | `true` after `POST /onboarding/complete`; `false` after signup | splash routes signed-in-but-incomplete users back into the flow |

## Notes for the backend

- `connectedSources` is **detected on the device** from Health Connect (Android)
  / HealthKit (iOS) — the distinct `sourceName`s of the user's health samples —
  and sent up via `PATCH /onboarding`. The server only stores them.
- `GET /onboarding` must return whatever was last persisted so back-navigation
  and app-restart resume show the user's saved answers.
