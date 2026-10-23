///|
test "recurrence expands weekly events into independent day snapshots" {
  let input = "day 09:00 18:00\nrepeat 0 7 busy standup 09:30 10:00\nrepeat 2 7 fixed exam 14:00 15:00"
  let days = expand_recurrence(input, 10).unwrap()
  assert_eq(days.length(), 10)
  assert_eq(days[0].event_count, 1)
  assert_eq(days[2].event_count, 1)
  assert_eq(days[7].event_count, 1)
  assert_eq(days[2].text.contains("fixed exam"), true)
}

///|
test "recurrence rejects invalid periods and missing templates" {
  assert_true(expand_recurrence("repeat 0 0 busy a 09:00 10:00", 3) is Err(_))
  assert_true(expand_recurrence("repeat 0 1 busy a 09:00 10:00", 3) is Err(_))
}
