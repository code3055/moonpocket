///|
/// A repeated event in a cycle-indexed calendar.
pub(all) struct RecurringEvent {
  day : Int
  period : Int
  kind : String
  id : String
  start : String
  end : String
} derive(ToJson)

///|
/// One expanded day, suitable for analyze_schedule or the CLI format.
pub(all) struct ExpandedDay {
  day_index : Int
  text : String
  event_count : Int
} derive(ToJson)

///|
fn recurrence_int(text : String, maximum : Int) -> Int? {
  if text.length() == 0 || text.length() > 6 {
    return None
  }
  let mut value = 0
  for c in text {
    if c < '0' || c > '9' {
      return None
    }
    value = value * 10 + c.to_int() - 48
    if value > maximum {
      return None
    }
  }
  Some(value)
}

///|
fn recurrence_id(text : String) -> Bool {
  if text.length() == 0 || text.length() > 64 {
    return false
  }
  for c in text {
    if !((c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '_' ||
      c == '-') {
      return false
    }
  }
  true
}

///|
fn recurrence_kind(text : String) -> Bool {
  text == "busy" || text == "fixed"
}

///|
/// Expand lines of the form `repeat FIRST PERIOD KIND ID START END`.
/// `FIRST` and `PERIOD` are zero-based cycle days. The day template is shared
/// by every expanded day, while each repeated event is emitted on matching days.
pub fn expand_recurrence(
  text : String,
  days : Int,
) -> Result[Array[ExpandedDay], String] {
  if days < 1 || days > 366 {
    return Err("days must be 1..366")
  }
  let mut template : String? = None
  let repeats : Array[RecurringEvent] = []
  let rows = words(text)
  for line = 0; line < rows.length(); line = line + 1 {
    let row = rows[line]
    let error = "recurrence line " + (line + 1).to_string() + ": "
    if row.length() == 0 {
      continue
    }
    if row[0] == "day" {
      if row.length() != 3 || template is Some(_) {
        return Err(error + "expected exactly one day START END")
      }
      match (time(row[1], false), time(row[2], true)) {
        (Some(s), Some(e)) if s < e =>
          template = Some("day " + row[1] + " " + row[2])
        _ => return Err(error + "invalid day window")
      }
      continue
    }
    if row.length() != 7 || row[0] != "repeat" {
      return Err(error + "expected repeat FIRST PERIOD KIND ID START END")
    }
    let first = match recurrence_int(row[1], days - 1) {
      Some(v) => v
      None => return Err(error + "invalid first day")
    }
    let period = match recurrence_int(row[2], days) {
      Some(v) if v > 0 => v
      _ => return Err(error + "period must be positive")
    }
    if !recurrence_kind(row[3]) || !recurrence_id(row[4]) {
      return Err(error + "invalid kind or event identifier")
    }
    match (time(row[5], false), time(row[6], true)) {
      (Some(s), Some(e)) if s < e =>
        repeats.push({
          day: first,
          period,
          kind: row[3],
          id: row[4],
          start: row[5],
          end: row[6],
        })
      _ => return Err(error + "invalid event window")
    }
  }
  let header = match template {
    Some(value) => value
    None => return Err("missing day template")
  }
  let expanded : Array[ExpandedDay] = []
  for day = 0; day < days; day = day + 1 {
    let output : Array[String] = []
    output.push(header)
    let mut count = 0
    for event in repeats {
      if day >= event.day && (day - event.day) % event.period == 0 {
        output.push(
          event.kind + " " + event.id + " " + event.start + " " + event.end,
        )
        count = count + 1
      }
    }
    let mut rendered = ""
    for row in output {
      rendered = rendered + row + "\n"
    }
    expanded.push({ day_index: day, text: rendered, event_count: count, })
  }
  Ok(expanded)
}

///|
pub extend RecurringEvent with ToJson::{to_json}

///|
pub extend ExpandedDay with ToJson::{to_json}
