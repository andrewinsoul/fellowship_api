defmodule FellowshipApi.MeetingsTest do
  use ExUnit.Case, async: true
  alias FellowshipApi.Meetings.Meeting

  test "meeting changeset requires valid times and status" do
    changeset =
      Meeting.changeset(%Meeting{}, %{
        title: "Monday Fellowship",
        starts_at: ~U[2026-10-19 18:00:00Z],
        ends_at: ~U[2026-10-19 20:00:00Z],
        status: "scheduled"
      })

    assert changeset.valid?
  end
end
