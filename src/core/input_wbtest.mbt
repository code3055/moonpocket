///|
test "BOM and trailing comments keep ordinary snapshots usable" {
  let plain = "day 09:00 12:00\nbusy lunch 10:00 11:00"
  let annotated = "\u{FEFF}# exported file\r\nday 09:00 12:00 # morning\r\nbusy lunch 10:00 11:00\t# protected time\r\n"
  match (analyze_text(plain, 45, 10), analyze_text(annotated, 45, 10)) {
    (Ok(a), Ok(b)) => assert_eq(a, b)
    _ => fail("annotated snapshot was rejected")
  }
}

///|
test "inline comments preserve error line numbers and do not hide malformed IDs" {
  match
    analyze_text(
      "# note\nday 09:00 12:00 # morning\nbusy a 08:00 10:00 # outside", 45, 10,
    ) {
    Err(e) => assert_eq(e, "line 3: busy a is outside day")
    Ok(_) => fail("out of bounds accepted")
  }
  match analyze_text("day 09:00 12:00\nbusy a#b 10:00 11:00", 45, 10) {
    Err(e) => assert_eq(e, "line 2: invalid identifier")
    Ok(_) => fail("invalid id accepted")
  }
}
