///|
test "dated recurrence validates dates, applies exceptions and timezone date" {
  let input = "day 09:00 18:00\nrepeat 0 1 busy standup 09:30 10:00"
  let days = expand_dated_recurrence(input, "2026-02-28", 3, 480, ["2026-03-01"]).unwrap()
  assert_eq(days[0].date, "2026-02-28")
  assert_eq(days[0].utc_date, "2026-02-27")
  assert_eq(days[1].date, "2026-03-01")
  assert_eq(days[1].skipped, true)
  assert_true(expand_dated_recurrence(input, "2026-02-30", 1, 0, []) is Err(_))
}
