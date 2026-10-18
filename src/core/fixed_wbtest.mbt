///|
test "fixed appointments occupy time but cannot be suggested for removal" {
  match analyze("day 09:00 12:00\nfixed exam 10:00 11:00", 45, 10) {
    Err(e) => fail(e)
    Ok(r) => {
      assert_eq(r.summary.busy_minutes, 60)
      assert_eq(r.summary.focus_minutes, 110)
      assert_eq(r.suggestions.length(), 0)
      assert_eq(r.events[0].fixed, true)
    }
  }
}

///|
test "removing an overlapping busy event cannot remove fixed time" {
  match
    analyze(
      "day 09:00 12:00\nbusy review 09:30 10:30\nfixed exam 10:00 11:00", 45, 10,
    ) {
    Err(e) => fail(e)
    Ok(r) => {
      assert_eq(r.suggestions.length(), 1)
      assert_eq(r.suggestions[0].event_id, "review")
      assert_eq(r.suggestions[0].gain_minutes, 60)
    }
  }
}
