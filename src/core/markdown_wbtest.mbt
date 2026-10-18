///|
test "Markdown lists usable starts and handles days without focus" {
  match markdown_from_text("day 09:00 12:00\nfixed exam 10:00 11:00", 45, 10) {
    Err(e) => fail(e)
    Ok(s) => assert_eq(s.contains("| 11:10 | 12:00 | 50 |"), true)
  }
  match markdown_from_text("day 09:00 09:30", 45, 10) {
    Err(e) => fail(e)
    Ok(s) => assert_eq(s.contains("No pocket meets"), true)
  }
}
