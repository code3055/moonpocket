///|
pub fn markdown_from_text(
  text : String,
  min_focus : Int,
  recovery : Int,
) -> Result[String, String] {
  match analyze(text, min_focus, recovery) {
    Err(e) => Err(e)
    Ok(r) => {
      let mut out = "# MoonPocket focus report\n\nDay: " +
        r.day.start +
        "–" +
        r.day.end +
        "\n\nFocus: **" +
        r.summary.focus_minutes.to_string() +
        " min** · Free: " +
        r.summary.free_minutes.to_string() +
        " min · Largest focus: " +
        r.summary.largest_focus.to_string() +
        " min\n\nMinimum focus: " +
        min_focus.to_string() +
        " min · Recovery: " +
        recovery.to_string() +
        " min\n\n## Focus pockets\n\n| Start | End | Minutes |\n| --- | --- | --- |\n"
      for p in r.pockets {
        if p.focus {
          out = out +
            "| " +
            p.usable_start +
            " | " +
            p.end +
            " | " +
            p.usable_minutes.to_string() +
            " |\n"
        }
      }
      if r.summary.focus_count == 0 {
        out = out + "\nNo pocket meets the focus threshold.\n"
      }
      out = out +
        "\n## Reclaim simulations\n\n| Move out of day | Gain (min) | Largest focus after move (min) |\n| --- | --- | --- |\n"
      for s in r.suggestions {
        out = out +
          "| `" +
          s.event_id +
          "` | " +
          s.gain_minutes.to_string() +
          " | " +
          s.largest_focus.to_string() +
          " |\n"
      }
      if r.suggestions.length() == 0 {
        out = out + "\nNo movable appointment increases focus time.\n"
      }
      Ok(
        out +
        "\nFixed commitments are excluded. Gains simulate moving one appointment out of this day; no schedule is modified.\n",
      )
    }
  }
}
