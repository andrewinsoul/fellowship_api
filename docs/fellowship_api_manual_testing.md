# Fellowship API --- Manual Testing Guide

This document describes the endpoints present in the current
`fellowship_api_copy.zip` source. It is intended for manually testing
the API with `curl`, Postman, Insomnia, or the VS Code REST Client.

> **Important:** The routes in the current router are prefixed with
> `/api/v1`. Older examples in the repository README and
> `docs/api-examples.http` use `/api` and are stale. Use the `/api/v1`
> paths documented here.

## 1. Start the API

From the project root:

``` bash
mix setup
mix run priv/repo/seeds.exs
mix phx.server
```

The API should be available at:

``` text
http://localhost:4000
```

Set a base URL variable for `curl` examples:

``` bash
export API="http://localhost:4000/api/v1"
```

Most responses are JSON. Send `Content-Type: application/json` when
submitting a JSON body.

## 2. Authentication

Authenticated endpoints require a bearer token:

``` http
Authorization: Bearer YOUR_TOKEN
```

The token is returned by registration or login. The current token is a
Phoenix-signed token that expires after 30 days. Logout tells the client
to discard the token; it does not revoke it server-side.

## 3. Endpoint overview

### Public endpoints

  -------------------------------------------------------------------------
  Method                  Path                      Purpose
  ----------------------- ------------------------- -----------------------
  `GET`                   `/health`                 Health check

  `POST`                  `/auth/register`          Register a first-time
                                                    visitor and record
                                                    attendance in one
                                                    transaction

  `POST`                  `/auth/login`             Sign in with phone
                                                    number or email and
                                                    password

  `POST`                  `/auth/forgot-password`   Placeholder;
                                                    password-recovery
                                                    delivery is not
                                                    implemented

  `GET`                   `/meetings/next`          Retrieve the next
                                                    scheduled meeting

  `GET`                   `/check-in/session`       Check whether a meeting
                                                    is currently accepting
                                                    check-ins

  `GET`                   `/quotations`             Retrieve published
                                                    quotations, paginated

  `GET`                   `/quotations/latest`      Retrieve the latest
                                                    published quotation
  -------------------------------------------------------------------------

### Authenticated endpoints

  -----------------------------------------------------------------------------
  Method                  Path                          Purpose
  ----------------------- ----------------------------- -----------------------
  `GET`                   `/home`                       Dashboard data

  `POST`                  `/auth/logout`                Tell the client to
                                                        discard its token

  `GET`                   `/profile`                    Retrieve the current
                                                        member profile

  `PATCH`                 `/profile`                    Update supported
                                                        profile fields

  `GET`                   `/attendance`                 Retrieve the current
                                                        member's attendance
                                                        history, paginated

  `POST`                  `/attendance/check-in`        Check in to the
                                                        currently open meeting

  `GET`                   `/notification-preferences`   Retrieve notification
                                                        preferences

  `PATCH`                 `/notification-preferences`   Update notification
                                                        preferences
  -----------------------------------------------------------------------------

Full paths are formed by adding `API` to each path above,
e.g. `GET $API/health`.

## 4. Health check

### Request

``` bash
curl -i "$API/health"
```

### Example response

``` json
{
  "status": "ok",
  "service": "fellowship_api"
}
```

## 5. Check whether check-in is open

This endpoint is public and does not require a token.

### Request

``` bash
curl -i "$API/check-in/session"
```

### Example response when a meeting is open

``` json
{
  "data": {
    "check_in_open": true,
    "meeting": {
      "id": 1,
      "title": "Monday Fellowship",
      "starts_at": "2026-10-19T18:00:00Z",
      "ends_at": "2026-10-19T20:00:00Z",
      "status": "scheduled",
      "timezone": "Africa/Lagos"
    }
  }
}
```

### Example response when no meeting is open

``` json
{
  "data": {
    "check_in_open": false,
    "meeting": null
  }
}
```

The times above are illustrative. Actual values come from the database.
Meetings are scheduled for Mondays, 7:00 PM--9:00 PM in `Africa/Lagos`.
The endpoint reports the meeting whose check-in window is open now.

## 6. Register and check in

Registration is intentionally coupled to attendance. It only succeeds
while a meeting is currently accepting check-ins. Member creation and
attendance recording are performed in one database transaction.

### Request

``` bash
curl -i -X POST "$API/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "full_name": "Jane Doe",
    "email": "jane@example.com",
    "phone_number": "+2348012345678",
    "password": "a-long-password",
    "gender": "female",
    "residence_address": "Ikeja, Lagos"
  }'
```

**Required fields in the current code:** `full_name`, `phone_number`,
`password`, `gender`, and `residence_address`. The migration also
declares `email` as `NOT NULL`, so provide an email even though the
changeset does not list it as required.

Allowed `gender` values are `"male"` and `"female"`. Password length
must be at least 8 characters and at most 72 characters.

### Example success response (`201 Created`)

``` json
{
  "data": {
    "member": {
      "id": 1,
      "full_name": "Jane Doe",
      "email": "jane@example.com",
      "phone_number": "+2348012345678",
      "status": "active"
    },
    "token": "COPY_TOKEN_FROM_RESPONSE",
    "attendance": null,
    "message": "Your account has been created. You can check in when a meeting is accepting attendance."
  }
}
```

The response is illustrative; IDs and timestamps will differ.

Registration does not depend on an open meeting. If no meeting is accepting check-ins, registration still succeeds and `attendance` is `null`. The authenticated attendance check-in endpoint continues to return `422` with `check_in_closed` when the session is closed.

### Example error: validation failed (`422 Unprocessable Entity`)

``` json
{
  "error": {
    "code": "validation_failed",
    "message": "Please check the submitted details.",
    "details": {
      "phone_number": ["has already been taken"]
    }
  }
}
```

The exact `details` depend on the validation failure. If registration
fails, the transaction does not leave behind a newly created member
without attendance.

Save the returned token for authenticated requests:

``` bash
export TOKEN="COPY_TOKEN_FROM_RESPONSE"
```

## 7. Sign in

Use either a member's phone number or email address as `login`.

### Request

``` bash
curl -i -X POST "$API/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "login": "+2348012345678",
    "password": "a-long-password"
  }'
```

You can also use:

``` json
{
  "login": "jane@example.com",
  "password": "a-long-password"
}
```

### Example success response

``` json
{
  "data": {
    "member": {
      "id": 1,
      "full_name": "Jane Doe",
      "email": "jane@example.com",
      "phone_number": "+2348012345678",
      "status": "active"
    },
    "token": "COPY_TOKEN_FROM_RESPONSE"
  }
}
```

Invalid credentials return `401 Unauthorized`:

``` json
{
  "error": {
    "code": "invalid_credentials",
    "message": "The details provided could not be verified."
  }
}
```

## 8. Dashboard / home

Requires authentication.

### Request

``` bash
curl -i "$API/home" \
  -H "Authorization: Bearer $TOKEN"
```

### Response shape

``` json
{
  "data": {
    "member": {
      "id": 1,
      "full_name": "Jane Doe",
      "email": "jane@example.com",
      "phone_number": "+2348012345678",
      "status": "active"
    },
    "next_meeting": {
      "id": 1,
      "title": "Monday Fellowship",
      "starts_at": "2026-10-19T18:00:00Z",
      "ends_at": "2026-10-19T20:00:00Z",
      "timezone": "Africa/Lagos",
      "status": "scheduled"
    },
    "check_in": {
      "open": false,
      "already_checked_in": false
    },
    "latest_quotation": {
      "id": 1,
      "text": "Your word is a lamp for my feet, a light on my path.",
      "source": "Psalm 119:105",
      "published_at": "2026-10-12T00:00:00Z"
    },
    "notification_preferences": {
      "push_enabled": true,
      "email_enabled": true,
      "reminder_minutes": 60
    }
  }
}
```

Any of `next_meeting` or `latest_quotation` may be `null` if no matching
record exists. The example is illustrative.

## 9. Get the next meeting

Public endpoint.

``` bash
curl -i "$API/meetings/next"
```

Returns `{"data": null}` if no upcoming scheduled meeting exists;
otherwise `data` contains the meeting ID, title, start/end timestamps,
status, and timezone.

## 10. Check in to a meeting

Requires authentication. The backend determines the current meeting; the
client does not submit a member ID or meeting ID.

### Request

``` bash
curl -i -X POST "$API/attendance/check-in" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}'
```

### First successful check-in (`201 Created`)

``` json
{
  "data": {
    "status": "checked_in",
    "attendance": {
      "id": 1,
      "checked_in_at": "2026-10-19T18:05:00Z",
      "meeting": {
        "id": 1,
        "title": "Monday Fellowship",
        "starts_at": "2026-10-19T18:00:00Z",
        "ends_at": "2026-10-19T20:00:00Z"
      }
    },
    "message": "Check-in successful!"
  }
}
```

### Repeated check-in for the same meeting (`200 OK`)

``` json
{
  "data": {
    "status": "already_checked_in",
    "attendance": {
      "id": 1,
      "checked_in_at": "2026-10-19T18:05:00Z",
      "meeting": {
        "id": 1,
        "title": "Monday Fellowship",
        "starts_at": "2026-10-19T18:00:00Z",
        "ends_at": "2026-10-19T20:00:00Z"
      }
    },
    "message": "You have already checked in for this meeting."
  }
}
```

If no meeting is currently open, the endpoint returns
`422 Unprocessable Entity` with error code `check_in_closed`.

## 11. Attendance history (paginated)

Requires authentication. Results are scoped to the signed-in member.

### Query parameters

  ------------------------------------------------------------------------
  Parameter                                  Default Rules
  --------------------- ---------------------------- ---------------------
  `page`                                         `1` Positive integer;
                                                     invalid values fall
                                                     back to 1

  `page_size`                                   `20` Positive integer;
                                                     invalid values fall
                                                     back to 20; maximum
                                                     100
  ------------------------------------------------------------------------

### Request

``` bash
curl -i "$API/attendance?page=1&page_size=10" \
  -H "Authorization: Bearer $TOKEN"
```

### Example response

``` json
{
  "data": [
    {
      "id": 1,
      "checked_in_at": "2026-10-19T18:05:00Z",
      "meeting": {
        "id": 1,
        "title": "Monday Fellowship",
        "starts_at": "2026-10-19T18:00:00Z",
        "ends_at": "2026-10-19T20:00:00Z"
      }
    }
  ],
  "meta": {
    "page": 1,
    "page_size": 10,
    "total_entries": 1,
    "total_pages": 1,
    "has_previous_page": false,
    "has_next_page": false
  }
}
```

To fetch the next page, use `?page=2&page_size=10`. An empty result set
has `total_entries: 0` and `total_pages: 0`.

## 12. Published quotations (paginated)

Public endpoint.

### Request

``` bash
curl -i "$API/quotations?page=1&page_size=10"
```

Pagination uses the same `page` and `page_size` rules as attendance
history.

### Example response

``` json
{
  "data": [
    {
      "id": 1,
      "text": "Your word is a lamp for my feet, a light on my path.",
      "source": "Psalm 119:105",
      "published_at": "2026-10-12T00:00:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "page_size": 10,
    "total_entries": 1,
    "total_pages": 1,
    "has_previous_page": false,
    "has_next_page": false
  }
}
```

Only published quotations whose `published_at` is absent or not in the
future are returned.

## 13. Latest quotation

Public endpoint.

``` bash
curl -i "$API/quotations/latest"
```

Returns `{"data": null}` when no published quotation is available.
Otherwise, `data` contains `id`, `text`, `source`, and `published_at`.

## 14. Get the member profile

Requires authentication.

``` bash
curl -i "$API/profile" \
  -H "Authorization: Bearer $TOKEN"
```

The response contains the current member's `id`, `full_name`, `email`,
`phone_number`, and `status`.

> The current `member_json/1` response does **not** expose `gender` or
> `residence_address`, even though these fields exist on the schema.

## 15. Update the member profile

Requires authentication.

### Request

``` bash
curl -i -X PATCH "$API/profile" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "full_name": "Jane A. Doe",
    "email": "jane@example.com",
    "phone_number": "+2348012345678"
  }'
```

The current profile changeset permits `full_name`, `email`,
`phone_number`, `notification_push_enabled`,
`notification_email_enabled`, and `notification_reminder_minutes`.
Fields such as `gender` and `residence_address` are not currently cast
by this profile changeset, so sending them will not update them.

## 16. Notification preferences

### Read preferences

Requires authentication.

``` bash
curl -i "$API/notification-preferences" \
  -H "Authorization: Bearer $TOKEN"
```

Example:

``` json
{
  "data": {
    "push_enabled": true,
    "email_enabled": true,
    "reminder_minutes": 60
  }
}
```

### Update preferences

Requires authentication. Send only the values you want to change.

``` bash
curl -i -X PATCH "$API/notification-preferences" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "push_enabled": true,
    "email_enabled": false,
    "reminder_minutes": 30
  }'
```

`reminder_minutes` must be between `0` and `10080` (seven days). The
current endpoint updates preference fields in the member record;
notification delivery itself is not implemented by this endpoint.

## 17. Logout

Requires authentication.

``` bash
curl -i -X POST "$API/auth/logout" \
  -H "Authorization: Bearer $TOKEN"
```

Example response:

``` json
{
  "data": {
    "message": "Signed out. Discard the token on this device."
  }
}
```

Discard the token in the client. The current implementation does not
revoke the signed token on the server.

## 18. Forgot password

Public endpoint; recovery delivery is not implemented yet.

``` bash
curl -i -X POST "$API/auth/forgot-password" \
  -H "Content-Type: application/json" \
  -d '{
    "login": "jane@example.com"
  }'
```

The current controller ignores the submitted body and always returns a
generic message indicating that recovery instructions would be sent once
password recovery is configured. Do not treat this endpoint as a working
password reset flow.

## 19. Authentication failure example

Call any authenticated endpoint without a valid token:

``` bash
curl -i "$API/profile"
```

Expected status: `401 Unauthorized`.

Example response:

``` json
{
  "error": {
    "code": "unauthorized",
    "message": "Please sign in to continue."
  }
}
```

## 20. Important implementation notes

-   The actual route prefix is `/api/v1`, not `/api`.
-   Registration requires an open meeting and currently creates the
    member plus attendance atomically.
-   Existing members should use login, then call the authenticated
    check-in endpoint.
-   Check-in is accepted only during a scheduled meeting's start/end
    window.
-   Attendance is unique per member per meeting.
-   Meetings are intended for Monday 7:00 PM--9:00 PM `Africa/Lagos`;
    timestamps in responses are UTC.
-   The permanent QR code is a frontend URL. The backend does not
    receive QR image data; the PWA calls the check-in-session endpoint
    and then the check-in endpoint.
-   The current project has no admin endpoints for creating meetings or
    quotations.
-   The password-recovery endpoint is a placeholder.
-   Configure HTTPS, appropriate CORS origins, rate limiting, and
    production secrets before deploying publicly.
