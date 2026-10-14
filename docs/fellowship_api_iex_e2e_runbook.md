# Fellowship API --- End-to-End IEx Test Runbook

This runbook tests the running Phoenix API from IEx, in sequence, before
building the React/Next.js PWA. It exercises the actual router,
controllers, authentication plug, contexts, and PostgreSQL.

## Before you start

From the project root, run the migrations and seeds:

``` bash
mix ecto.migrate
mix run priv/repo/seeds.exs
```

Start the API with IEx:

``` bash
iex -S mix phx.server
```

The server should report that it is listening on
`http://localhost:4000`.

### Two startup checks

1.  Ensure the Oban migration has been added and run. Your earlier
    `oban_peers does not exist` error means Oban's tables were missing
    at that point.

2.  Fix the `MeetingsJson.render/1 is undefined` compile warning in
    `lib/fellowship_api_web/controllers/home_controller.ex` by adding:

    ``` elixir
    alias FellowshipApiWeb.MeetingsJson
    ```

    `HomeController` calls `MeetingsJson.render/1`, but the module is
    `FellowshipApiWeb.MeetingsJson`. After editing, run `recompile()` in
    IEx. Resolve compile warnings/errors before proceeding.

## Important: attendance is only open during a meeting

The application accepts check-ins only when a scheduled meeting's
`starts_at <= now <= ends_at`.

Your regular meeting is Monday 7:00 PM--9:00 PM `Africa/Lagos`. If
you're testing outside that window, registration-and-check-in and the
check-in endpoint should return `check_in_closed`.

To test the full flow at any time, the steps below create a temporary
meeting that is open now. This is for local development only; do not run
this fixture setup against production.

## 1. Define a small HTTP helper in IEx

Paste this entire block into the running IEx shell. It calls the local
Phoenix endpoint directly, so you can test routes without switching to
`curl` or adding an HTTP client dependency.

``` elixir
defmodule IExAPI do
  def request(method, path, body \\ nil, token \\ nil) do
    request_body = if is_nil(body), do: "", else: Jason.encode!(body)

    conn =
      Plug.Test.conn(method, path, request_body)
      |> Plug.Conn.put_req_header("accept", "application/json")

    conn =
      if is_nil(body) do
        conn
      else
        Plug.Conn.put_req_header(conn, "content-type", "application/json")
      end

    conn =
      if is_binary(token) do
        Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
      else
        conn
      end

    conn = FellowshipApiWeb.Endpoint.call(conn, [])
    response = Jason.decode!(conn.resp_body)
    IO.inspect({conn.status, response}, label: "#{method |> to_string() |> String.upcase()} #{path}")
    {conn.status, response}
  end
end
```

If you edit the helper and redefine it later, IEx may print a
module-redefinition notice; that is fine.

## 2. Check the health endpoint

``` elixir
IExAPI.request(:get, "/api/v1/health")
```

Expect HTTP `200` and a response with `"status" => "ok"`.

## 3. Check check-in status before creating a test meeting

``` elixir
IExAPI.request(:get, "/api/v1/check-in/session")
```

Outside a meeting window, expect `"check_in_open" => false` and
`"meeting" => nil` (unless another open meeting already exists).

## 4. Create a temporary meeting open now

This step creates a one-off test meeting with a start time one minute
ago and an end time one hour from now. The timestamps are stored as UTC
instants, as expected by the schema.

``` elixir
alias FellowshipApi.Repo
alias FellowshipApi.Meetings.Meeting

now = DateTime.utc_now() |> DateTime.truncate(:second)
test_starts_at = DateTime.add(now, -60, :second)
test_ends_at = DateTime.add(now, 3600, :second)

{:ok, test_meeting} =
  %Meeting{}
  |> Meeting.changeset(%{
    title: "IEx End-to-End Test Meeting",
    starts_at: test_starts_at,
    ends_at: test_ends_at,
    status: "scheduled"
  })
  |> Repo.insert()

test_meeting.id
```

Keep `test_meeting.id` for cleanup at the end. If the insert fails with
a unique constraint error, inspect existing meetings with the same
`starts_at` and use a new timestamp.

Now check again:

``` elixir
IExAPI.request(:get, "/api/v1/check-in/session")
```

Expect `"check_in_open" => true` and the test meeting in the response.

## 5. Register a first-time member and record attendance

Use a unique email and phone number each time you repeat this test.
Change the final digits if needed.

``` elixir
registration = %{
  "full_name" => "IEx Test Member",
  "email" => "iex.test.member.20261014@example.com",
  "phone_number" => "+2348099900101",
  "password" => "test-password-123",
  "gender" => "female",
  "residence_address" => "Ikeja, Lagos"
}

{201, registration_response} =
  IExAPI.request(:post, "/api/v1/auth/register", registration)

member = registration_response["data"]["member"]
token = registration_response["data"]["token"]
first_attendance = registration_response["data"]["attendance"]

member
token
first_attendance
```

Expected: - HTTP `201`. - A member object. - A bearer token. - An
attendance record linked to the open test meeting.

Registration and attendance should be atomic: if attendance insertion
fails, the member creation should roll back too.

If you receive `422 check_in_closed`, check the test meeting timestamps
and ensure no unexpected time has elapsed or that the meeting was not
cancelled.

## 6. Sign in using the email

``` elixir
{200, login_response} =
  IExAPI.request(:post, "/api/v1/auth/login", %{
    "login" => registration["email"],
    "password" => registration["password"]
  })

token = login_response["data"]["token"]
token
```

Expected HTTP `200`, member data, and a token. You can also test login
using the phone number in the `login` field.

## 7. Check in again --- verify duplicate protection

``` elixir
{200, duplicate_response} =
  IExAPI.request(:post, "/api/v1/attendance/check-in", %{}, token)

duplicate_response["data"]["status"]
```

Expected status value: `"already_checked_in"`. It must not create a
second attendance record for this member and meeting.

To verify the database count directly:

``` elixir
alias FellowshipApi.Attendance.AttendanceRecord
import Ecto.Query

Repo.aggregate(
  from(a in AttendanceRecord,
    where: a.member_id == ^member["id"] and a.meeting_id == ^test_meeting.id
  ),
  :count,
  :id
)
```

Expected result: `1`.

## 8. Test the authenticated home/dashboard endpoint

``` elixir
IExAPI.request(:get, "/api/v1/home", nil, token)
```

Expect HTTP `200` with member data, the next meeting, check-in state,
latest quotation, and notification preferences. If the `MeetingsJson`
warning has not been fixed, address that first.

## 9. Test the profile endpoint

``` elixir
IExAPI.request(:get, "/api/v1/profile", nil, token)
```

Update the profile:

``` elixir
IExAPI.request(
  :patch,
  "/api/v1/profile",
  %{
    "full_name" => "IEx Test Member Updated",
    "phone_number" => registration["phone_number"]
  },
  token
)
```

Expect HTTP `200` and the updated name.

Note: the current profile changeset permits `full_name`, `email`,
`phone_number`, and notification fields. Although `gender` and
`residence_address` exist on the member schema, they are not currently
cast by `profile_changeset/2`.

## 10. Test notification preferences

Read them:

``` elixir
IExAPI.request(:get, "/api/v1/notification-preferences", nil, token)
```

Update them:

``` elixir
IExAPI.request(
  :patch,
  "/api/v1/notification-preferences",
  %{
    "push_enabled" => true,
    "email_enabled" => false,
    "reminder_minutes" => 30
  },
  token
)
```

Read them again and confirm the values changed:

``` elixir
IExAPI.request(:get, "/api/v1/notification-preferences", nil, token)
```

Try an invalid reminder value to verify validation:

``` elixir
IExAPI.request(
  :patch,
  "/api/v1/notification-preferences",
  %{"reminder_minutes" => 20000},
  token
)
```

Expect HTTP `422`.

## 11. Test paginated attendance history

``` elixir
IExAPI.request(:get, "/api/v1/attendance?page=1&page_size=10", nil, token)
```

Expect `data` to be a list and `meta` to contain `page`, `page_size`,
`total_entries`, `total_pages`, `has_previous_page`, and
`has_next_page`.

Test malformed pagination values:

``` elixir
IExAPI.request(:get, "/api/v1/attendance?page=abc&page_size=1000", nil, token)
```

The current pagination parser should fall back to page 1 and cap page
size at 100.

## 12. Test quotations

List published quotations with pagination:

``` elixir
IExAPI.request(:get, "/api/v1/quotations?page=1&page_size=10")
```

Get the latest quotation:

``` elixir
IExAPI.request(:get, "/api/v1/quotations/latest")
```

If the quotation list is empty, run the seed file from the project root
in a separate shell:

``` bash
mix run priv/repo/seeds.exs
```

Then retry the requests.

## 13. Test the next meeting endpoint

``` elixir
IExAPI.request(:get, "/api/v1/meetings/next")
```

Expect the earliest scheduled meeting whose `ends_at` has not passed, or
`data: nil` if none exists.

## 14. Test unauthenticated access

``` elixir
IExAPI.request(:get, "/api/v1/profile")
```

Expect HTTP `401` with error code `"unauthorized"`.

Also test an invalid token:

``` elixir
IExAPI.request(:get, "/api/v1/profile", nil, "not-a-real-token")
```

Expect HTTP `401`.

## 15. Test logout

``` elixir
IExAPI.request(:post, "/api/v1/auth/logout", %{}, token)
```

Expect HTTP `200` and the sign-out message.

Important: the current logout endpoint tells the client to discard its
token; it does not revoke the Phoenix token server-side. The token
remains usable until it expires, so test this as the current behaviour
rather than expecting revocation.

## 16. Test the closed check-in window

To prove check-in is rejected when no meeting is open, cancel the
temporary meeting:

``` elixir
{:ok, cancelled_test_meeting} =
  test_meeting
  |> Meeting.changeset(%{status: "cancelled"})
  |> Repo.update()
```

Then check the session:

``` elixir
IExAPI.request(:get, "/api/v1/check-in/session")
```

If no other meeting is open, expect `"check_in_open" => false`.

Try check-in:

``` elixir
IExAPI.request(:post, "/api/v1/attendance/check-in", %{}, token)
```

Expect HTTP `422` with error code `"check_in_closed"`.

## 17. Test the meeting-generation worker

The worker is intended to ensure the next 12 Monday occurrences exist.
Call it directly to test its result:

``` elixir
FellowshipApi.Workers.EnsureUpcomingMeetings.perform(%Oban.Job{})
```

Expected result: `:ok`.

Then inspect the upcoming meetings:

``` elixir
FellowshipApi.Meetings.list_upcoming(12)
```

The meetings should be Mondays at 7 PM--9 PM `Africa/Lagos`, stored as
UTC timestamps. Running the worker repeatedly should not create
duplicates because the database has a unique index on `starts_at`.

If the worker implementation in your working tree uses the batch
function `ensure_meetings_for_dates/1`, verify that function exists and
returns the shape the worker expects before running this step.

## 18. Optional cleanup of the temporary test data

Only do this if you want to remove the temporary meeting and test member
after you finish inspecting the results. Attendance rows reference both
records, so delete attendance first.

``` elixir
Repo.delete_all(
  from(a in AttendanceRecord,
    where: a.member_id == ^member["id"] and a.meeting_id == ^test_meeting.id
  )
)

Repo.delete_all(
  from(a in AttendanceRecord, where: a.member_id == ^member["id"])
)

Repo.delete_all(
  from(m in Meeting, where: m.id == ^test_meeting.id)
)

Repo.delete_all(
  from(m in FellowshipApi.Accounts.Member, where: m.id == ^member["id"])
)
```

If you want to retain the test member for more experiments, skip
cleanup.

## Completion checklist

Before starting the PWA, confirm:

-   [ ] API boots with no compile warnings that affect these routes.
-   [ ] Health, meeting session, next meeting, and quotations endpoints
    work.
-   [ ] Registration creates a member and one attendance record in one
    transaction.
-   [ ] Login returns a usable token.
-   [ ] Authenticated routes accept the token; missing/invalid tokens
    return `401`.
-   [ ] Repeat check-in returns `already_checked_in` and the database
    count remains `1`.
-   [ ] Attendance and quotation pagination metadata is correct.
-   [ ] Profile and notification preferences can be read and updated.
-   [ ] Closed check-in windows reject registration/check-in.
-   [ ] The meeting-generation worker is idempotent.
-   [ ] Oban tables exist and Oban starts without `oban_peers` errors.

Once these pass, the backend is in a good position to integrate with the
React/Next.js PWA.
