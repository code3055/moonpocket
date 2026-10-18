///|
test "empty day and lunch recovery" {
  match analyze("day 09:00 18:00", 45, 10) {
    Err(e) => fail(e)
    Ok(r) => {
      assert_eq(r.summary.focus_minutes, 540)
      assert_eq(r.summary.busy_minutes, 0)
      assert_eq(r.summary.focus_count, 1)
    }
  }
  match analyze("day 09:00 18:00\nbusy lunch 12:00 13:00", 45, 10) {
    Err(e) => fail(e)
    Ok(r) => {
      assert_eq(r.summary.focus_minutes, 470)
      assert_eq(r.summary.fragment_minutes, 10)
      assert_eq(r.summary.largest_focus, 290)
    }
  }
}

///|
test "overlapping and touching arrangements are counted once" {
  match
    analyze(
      "day 09:00 12:00\nbusy c 10:30 11:00\nbusy b 10:00 10:30\nbusy a 09:30 10:15",
      20, 10,
    ) {
    Err(e) => fail(e)
    Ok(r) => {
      assert_eq(r.summary.busy_minutes, 90)
      assert_eq(r.summary.free_minutes, 90)
      assert_eq(r.summary.focus_minutes, 80)
      assert_eq(r.pockets.length(), 2)
    }
  }
}

///|
test "threshold inclusive and recovery clamps to gap" {
  match analyze("day 09:00 10:00\nbusy a 09:00 09:05", 45, 10) {
    Err(e) => fail(e)
    Ok(r) => assert_eq(r.summary.focus_minutes, 45)
  }
  match analyze("day 09:00 10:00\nbusy a 09:00 09:05", 46, 10) {
    Err(e) => fail(e)
    Ok(r) => {
      assert_eq(r.summary.focus_minutes, 0)
      assert_eq(r.summary.largest_focus, 0)
    }
  }
  match analyze("day 09:00 10:00\nbusy a 09:00 09:55", 1, 10) {
    Err(e) => fail(e)
    Ok(r) => {
      assert_eq(r.pockets[0].usable_minutes, 0)
      assert_eq(r.summary.focus_minutes, 0)
    }
  }
}

///|
test "removal simulation remerges overlapping events" {
  match
    analyze("day 09:00 12:00\nbusy a 09:30 10:30\nbusy b 09:30 10:30", 45, 10) {
    Err(e) => fail(e)
    Ok(r) => {
      assert_eq(r.suggestions.length(), 0)
      assert_eq(r.summary.focus_minutes, 80)
    }
  }
}

///|
test "strict malformed input and parameter checks" {
  for
    text in [
      "", "day 9:00 18:00", "day 09:00 09:00", "day 09:00 18:00\nday 09:00 18:00",
      "day 09:00 18:00\nbusy a 08:00 10:00", "day 09:00 18:00\nbusy a 10:00 10:00",
      "day 09:00 18:00\nbusy a 09:30 10:00\nbusy a 11:00 11:30", "day 09:00 18:00\nbusy <tag> 10:00 11:00",
      "day 24:00 24:00", "day 09:00 18:60",
    ] {
    match analyze_text(text, 45, 10) {
      Err(_) => ()
      Ok(_) => fail("accepted invalid input: " + text)
    }
  }
  match analyze_text("day 09:00 18:00", 0, 10) {
    Err(_) => ()
    Ok(_) => fail("accepted zero threshold")
  }
  match analyze_text("day 09:00 18:00", 45, -1) {
    Err(_) => ()
    Ok(_) => fail("accepted negative recovery")
  }
}

///|
test "comments whitespace midnight and deterministic outputs" {
  let a = "# comment\r\nday\t00:00 24:00\n\nbusy z 12:00 13:00\nbusy a 09:00 10:00"
  let b = "day 00:00 24:00\nbusy a 09:00 10:00\nbusy z 12:00 13:00"
  match (analyze_text(a, 45, 10), analyze_text(b, 45, 10)) {
    (Ok(x), Ok(y)) => assert_eq(x, y)
    _ => fail("valid snapshot rejected")
  }
}
