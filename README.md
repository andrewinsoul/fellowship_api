# Fellowship API

Phoenix JSON API backend for the Fellowship PWA concept. This starter provides member authentication, meeting lookup, QR check-in, attendance history, quotations, profile/preferences endpoints, PostgreSQL migrations, and an Oban Cron worker that maintains a rolling window of Monday meetings.

## Domain decisions included

- The venue QR code is permanent and should point to the PWA check-in route. It does not contain a member ID or meeting ID.
- Meetings normally occur Mondays from **7:00 PM to 9:00 PM in `Africa/Lagos`**.
- The worker keeps a rolling 12-week window of meeting occurrences. The attendance service only accepts check-in while a scheduled meeting is currently open.
- Each member can have at most one attendance record per meeting, enforced by a PostgreSQL unique index on `(member_id, meeting_id)`.
- New-member registration initiated from check-in creates the member and attendance in one Ecto transaction.
- There is no admin API/UI in this first version.

## Requirements

- Elixir 1.15+ and Erlang/OTP compatible with it
- PostgreSQL 14+
- Mix

## Run locally

1. Start PostgreSQL:

   ```sh
   docker compose up -d db
   ```

2. Fetch dependencies, create the database, and migrate:

   ```sh
   mix setup
   ```

3. Seed sample quotations:

   ```sh
   mix run priv/repo/seeds.exs
   ```

4. Start the API:

   ```sh
   mix phx.server
   ```

The API listens on `http://localhost:4000`. Health check: `GET /api/health`.

The Cron plugin runs the meeting-generation worker every Tuesday at 00:15 according to the server's scheduler timezone. The worker calculates dates in `Africa/Lagos` and ensures the next 12 Monday occurrences exist. You can run it manually for testing:

```elixir
FellowshipApi.Workers.EnsureUpcomingMeetings.new(%{}) |> Oban.insert()
```

Or invoke the worker directly from IEx in a configured environment:

```elixir
FellowshipApi.Workers.EnsureUpcomingMeetings.perform(%Oban.Job{args: %{}})
```

## API overview

All request/response bodies use JSON. Authenticated routes require:

```http
Authorization: Bearer YOUR_TOKEN
```

### Public endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/health` | Health check |
| POST | `/api/auth/register` | Register a first-time visitor and record attendance atomically; only succeeds while check-in is open |
| POST | `/api/auth/login` | Authenticate an existing member |
| POST | `/api/auth/forgot-password` | Placeholder response; delivery flow is not implemented |
| GET | `/api/meetings/next` | Next scheduled meeting |
| GET | `/api/check-in/session` | Whether a meeting is currently accepting check-ins |
| GET | `/api/quotations` | Published quotations |
| GET | `/api/quotations/latest` | Latest published quotation |

### Authenticated endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/home` | Dashboard payload: member, next meeting, check-in state, latest quote, preferences |
| POST | `/api/auth/logout` | Client should discard bearer token; tokens are stateless |
| GET/PATCH | `/api/profile` | Read/update profile |
| GET | `/api/attendance` | Attendance history (`?limit=50`, max 100) |
| POST | `/api/attendance/check-in` | Check in to the currently open meeting |
| GET/PATCH | `/api/notification-preferences` | Read/update reminder preference settings |

### Register + check in

`POST /api/auth/register` expects JSON like:

```json
{
  "full_name": "Jane Doe",
  "email": "jane@example.com",
  "phone_number": "+2348012345678",
  "password": "a-long-password"
}
```

Registration is intentionally tied to check-in in this starter. It returns a bearer token and attendance record. If no meeting is currently open, nothing is created.

### Sign in

`POST /api/auth/login`:

```json
{
  "login": "+2348012345678",
  "password": "a-long-password"
}
```

The `login` value can be a phone number or email address.

### Check in

After sign-in, call `POST /api/attendance/check-in` with the bearer token and an empty JSON object. Repeated scans return `already_checked_in` instead of creating another record.

## PWA integration notes

- The QR code should encode a stable frontend URL such as `https://your-domain.example/check-in`; it should not encode a bearer token or a changing meeting ID.
- The scanner reads that URL, then the PWA calls `/api/check-in/session` and `/api/attendance/check-in`.
- The PWA should use `/api/auth/register` for first-time visitors who register while a meeting is open.
- Configure CORS at deployment if the PWA and API use different origins. This starter intentionally does not add a permissive wildcard CORS policy.
- A permanent QR code plus a time window does not prove physical presence. That risk was intentionally accepted for the initial version.

## Security and production work still required

This is a starter backend, not a production-audited service. Before production, add account verification and password-reset delivery, rate limiting on authentication/check-in endpoints, a production secret, explicit CORS origins, HTTPS, operational logging/monitoring, and tests for registration transactions and concurrent check-in. The stateless bearer token is signed by Phoenix and expires after 30 days; logout is client-side token removal. Consider short-lived access tokens plus refresh-token/session revocation if server-side logout is required.

`nature_whistle` is not added as a dependency automatically. It can be integrated as an independent observability layer once its configuration and alert thresholds are selected for this application.
