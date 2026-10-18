///|
test "calendar exports usable focus and rolls midnight into the next date" {
  match calendar_from_text("day 23:00 24:00", 45, 10, "2026-12-31") {
    Err(e) => fail(e)
    Ok(s) => {
      assert_eq(s.contains("DTSTART:20261231T230000"), true)
      assert_eq(s.contains("DTEND:20270101T000000"), true)
    }
  }
  match
    calendar_from_text(
      "day 09:00 12:00\nfixed exam 09:00 10:00", 45, 10, "2028-02-29",
    ) {
    Err(e) => fail(e)
    Ok(s) => assert_eq(s.contains("DTSTART:20280229T101000"), true)
  }
}

///|
test "calendar rejects invalid dates and returns an empty calendar without focus" {
  for
    date in [
      "2026-02-29", "2026-04-31", "2026-13-01", "2026-1-01", "0000-01-01", "9999-01-01",
    ] {
    match calendar_from_text("day 09:00 10:00", 45, 10, date) {
      Err(_) => ()
      Ok(_) => fail("invalid date accepted")
    }
  }
  match calendar_from_text("day 09:00 09:30", 45, 10, "2026-10-18") {
    Err(e) => fail(e)
    Ok(s) => assert_eq(s.contains("BEGIN:VEVENT"), false)
  }
}
