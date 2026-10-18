///|
test "SVG exposes labels tooltips and fixed commitments" {
  match svg_from_text("day 09:00 12:00\nfixed exam 10:00 11:00", 45, 10) {
    Err(e) => fail(e)
    Ok(s) => {
      assert_eq(
        s.contains("aria-labelledby=\"pocket-title pocket-desc\""),
        true,
      )
      assert_eq(s.contains("exam [fixed]"), true)
      assert_eq(s.contains("text-anchor=\"middle\""), true)
      assert_eq(s.contains("usable 50 min"), true)
    }
  }
}
