fn main {
  let before = "day 09:00 18:00\nbusy review 10:00 10:30"
  let after = "day 09:00 18:00\nbusy review 15:00 15:30"
  match @core.compare_schedules(before, after, 45, 10) {
    Err(message) => println(message)
    Ok(delta) => println("focus delta=" + delta.focus_delta.to_string())
  }
}
