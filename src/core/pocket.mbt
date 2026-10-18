///|
struct Event {
  id : String
  start : Int
  end : Int
} derive(ToJson)

///|
struct Pocket {
  start : String
  end : String
  usable_start : String
  usable_minutes : Int
  focus : Bool
} derive(ToJson)

///|
struct Summary {
  busy_minutes : Int
  free_minutes : Int
  focus_minutes : Int
  fragment_minutes : Int
  largest_focus : Int
  focus_count : Int
} derive(ToJson)

///|
struct Suggestion {
  event_id : String
  gain_minutes : Int
  largest_focus : Int
} derive(ToJson)

///|
struct Day {
  start : String
  end : String
} derive(ToJson)

///|
struct Settings {
  min_focus : Int
  recovery : Int
} derive(ToJson)

///|
struct Report {
  tool : String
  day : Day
  settings : Settings
  summary : Summary
  pockets : Array[Pocket]
  events : Array[Event]
  suggestions : Array[Suggestion]
} derive(ToJson)

///|
fn pad(n : Int) -> String {
  if n < 10 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
fn clock(n : Int) -> String {
  pad(n / 60) + ":" + pad(n % 60)
}

///|
fn time(s : String, ending : Bool) -> Int? {
  if s.length() != 5 {
    return None
  }
  let chars = s.iter().to_array()
  if chars[2] != ':' {
    return None
  }
  for i in [0, 1, 3, 4] {
    if chars[i] < '0' || chars[i] > '9' {
      return None
    }
  }
  let h = (chars[0].to_int() - 48) * 10 + chars[1].to_int() - 48
  let m = (chars[3].to_int() - 48) * 10 + chars[4].to_int() - 48
  if m > 59 || h > 24 || (h == 24 && (!ending || m != 0)) {
    None
  } else {
    Some(h * 60 + m)
  }
}

///|
fn words(s : String) -> Array[Array[String]] {
  let lines : Array[Array[String]] = []
  let mut row : Array[String] = []
  let mut word = ""
  for c in s {
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      if word != "" {
        row.push(word)
        word = ""
      }
      if c == '\n' {
        lines.push(row)
        row = []
      }
    } else {
      word = word + c.to_string()
    }
  }
  if word != "" {
    row.push(word)
  }
  lines.push(row)
  lines
}

///|
fn id_before(a : String, b : String) -> Bool {
  let ac = a.iter().to_array()
  let bc = b.iter().to_array()
  let length = if ac.length() < bc.length() { ac.length() } else { bc.length() }
  for i = 0; i < length; i = i + 1 {
    if ac[i] != bc[i] {
      return ac[i] < bc[i]
    }
  }
  ac.length() <= bc.length()
}

///|
fn parse(text : String) -> Result[(Int, Int, Array[Event]), String] {
  let events : Array[Event] = []
  let event_lines : Array[Int] = []
  let mut day : (Int, Int)? = None
  let rows = words(text)
  for i = 0; i < rows.length(); i = i + 1 {
    let row = rows[i]
    let error = "line " + (i + 1).to_string() + ": "
    if row.length() == 0 {
      continue
    }
    if row[0].iter().to_array()[0] == '#' {
      continue
    }
    if row[0] == "day" {
      if row.length() != 3 || day is Some(_) {
        return Err(error + "expected exactly one day START END")
      }
      match (time(row[1], false), time(row[2], true)) {
        (Some(s), Some(e)) => {
          if s >= e {
            return Err(error + "day must have positive duration")
          }
          day = Some((s, e))
        }
        _ => return Err(error + "invalid HH:MM time")
      }
    } else if row[0] == "busy" {
      if row.length() != 4 {
        return Err(error + "expected busy ID START END")
      }
      if row[1].length() > 64 {
        return Err(error + "identifier exceeds 64 characters")
      }
      for c in row[1] {
        if !((c >= 'a' && c <= 'z') ||
          (c >= 'A' && c <= 'Z') ||
          (c >= '0' && c <= '9') ||
          c == '_' ||
          c == '-') {
          return Err(error + "invalid identifier")
        }
      }
      for event in events {
        if event.id == row[1] {
          return Err(error + "duplicate identifier")
        }
      }
      if events.length() >= 200 {
        return Err(error + "at most 200 events")
      }
      match (time(row[2], false), time(row[3], true)) {
        (Some(s), Some(e)) => {
          if s >= e {
            return Err(error + "busy must have positive duration")
          }
          events.push({ id: row[1], start: s, end: e, })
          event_lines.push(i + 1)
        }
        _ => return Err(error + "invalid HH:MM time")
      }
    } else {
      return Err(error + "unknown directive")
    }
  }
  match day {
    None => Err("line 1: missing day START END")
    Some((s, e)) => {
      for i = 0; i < events.length(); i = i + 1 {
        let event = events[i]
        if event.start < s || event.end > e {
          return Err(
            "line " +
            event_lines[i].to_string() +
            ": busy " +
            event.id +
            " is outside day",
          )
        }
      }
      // Insertion sort gives deterministic event ordering, including tied intervals.
      for i = 1; i < events.length(); i = i + 1 {
        let mut j = i
        while j > 0 {
          let a = events[j - 1]
          let b = events[j]
          if a.start < b.start || (a.start == b.start && id_before(a.id, b.id)) {
            break
          }
          events[j - 1] = b
          events[j] = a
          j = j - 1
        }
      }
      Ok((s, e, events))
    }
  }
}

///|
fn calculate(
  start : Int,
  end : Int,
  events : Array[Event],
  minimum : Int,
  recovery : Int,
  skip : String,
) -> (Summary, Array[Pocket]) {
  let merged : Array[(Int, Int)] = []
  for event in events {
    if event.id == skip {
      continue
    }
    if merged.length() > 0 {
      let last = merged.length() - 1
      let (s, e) = merged[last]
      if event.start <= e {
        merged[last] = (s, if event.end > e { event.end } else { e })
        continue
      }
    }
    merged.push((event.start, event.end))
  }
  let pockets : Array[Pocket] = []
  let mut cursor = start
  let mut busy = 0
  let mut focus = 0
  let mut largest = 0
  let mut count = 0
  let mut after_busy = false
  for i = 0; i <= merged.length(); i = i + 1 {
    let next = if i < merged.length() { merged[i].0 } else { end }
    if next > cursor {
      let usable_start = if after_busy {
        if cursor + recovery > next {
          next
        } else {
          cursor + recovery
        }
      } else {
        cursor
      }
      let usable = next - usable_start
      let qualifies = usable >= minimum
      pockets.push({
        start: clock(cursor),
        end: clock(next),
        usable_start: clock(usable_start),
        usable_minutes: usable,
        focus: qualifies,
      })
      if qualifies {
        focus = focus + usable
        count = count + 1
        if usable > largest {
          largest = usable
        }
      }
    }
    if i < merged.length() {
      busy = busy + merged[i].1 - merged[i].0
      cursor = merged[i].1
      after_busy = true
    }
  }
  let free = end - start - busy
  (
    {
      busy_minutes: busy,
      free_minutes: free,
      focus_minutes: focus,
      fragment_minutes: free - focus,
      largest_focus: largest,
      focus_count: count,
    },
    pockets,
  )
}

///|
fn analyze(
  text : String,
  min_focus : Int,
  recovery : Int,
) -> Result[Report, String] {
  if min_focus < 1 || min_focus > 1440 || recovery < 0 || recovery > 1440 {
    return Err("min_focus must be 1..1440; recovery must be 0..1440")
  }
  match parse(text) {
    Err(e) => Err(e)
    Ok((start, end, events)) => {
      let (summary, pockets) = calculate(
        start, end, events, min_focus, recovery, "",
      )
      let suggestions : Array[Suggestion] = []
      for event in events {
        let (after, _) = calculate(
          start,
          end,
          events,
          min_focus,
          recovery,
          event.id,
        )
        let gain = after.focus_minutes - summary.focus_minutes
        if gain > 0 {
          suggestions.push({
            event_id: event.id,
            gain_minutes: gain,
            largest_focus: after.largest_focus,
          })
        }
      }
      for i = 1; i < suggestions.length(); i = i + 1 {
        let mut j = i
        while j > 0 {
          let a = suggestions[j - 1]
          let b = suggestions[j]
          if a.gain_minutes > b.gain_minutes ||
            (
              a.gain_minutes == b.gain_minutes &&
              id_before(a.event_id, b.event_id)
            ) {
            break
          }
          suggestions[j - 1] = b
          suggestions[j] = a
          j = j - 1
        }
      }
      Ok({
        tool: "MoonPocket",
        day: { start: clock(start), end: clock(end), },
        settings: { min_focus, recovery, },
        summary,
        pockets,
        events,
        suggestions,
      })
    }
  }
}

///|
pub fn analyze_text(
  text : String,
  min_focus : Int,
  recovery : Int,
) -> Result[String, String] {
  match analyze(text, min_focus, recovery) {
    Ok(report) => Ok(@json.to_json(report).stringify())
    Err(e) => Err(e)
  }
}

///|
pub fn svg_from_text(
  text : String,
  min_focus : Int,
  recovery : Int,
) -> Result[String, String] {
  match analyze(text, min_focus, recovery) {
    Err(e) => Err(e)
    Ok(report) => {
      let start = time(report.day.start, false).unwrap()
      let end = time(report.day.end, true).unwrap()
      let height = 270 +
        report.events.length() * 26 +
        report.suggestions.length() * 24
      let mut svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"960\" height=\"" +
        height.to_string() +
        "\" viewBox=\"0 0 960 " +
        height.to_string() +
        "\"><rect width=\"100%\" height=\"100%\" fill=\"#101b2d\"/><g font-family=\"Arial,sans-serif\" fill=\"#edf3ff\"><text x=\"36\" y=\"44\" font-size=\"28\">MoonPocket / time reclaimed</text><text x=\"36\" y=\"76\" font-size=\"16\">" +
        report.day.start +
        " - " +
        report.day.end +
        " | Focus " +
        report.summary.focus_minutes.to_string() +
        " min | Free " +
        report.summary.free_minutes.to_string() +
        " min | Fragment " +
        report.summary.fragment_minutes.to_string() +
        " min</text><rect x=\"36\" y=\"106\" width=\"888\" height=\"48\" rx=\"6\" fill=\"#475569\"/>"
      for pocket in report.pockets {
        let s = time(pocket.usable_start, true).unwrap()
        let e = time(pocket.end, true).unwrap()
        let x = 36 + (s - start) * 888 / (end - start)
        let w = (e - s) * 888 / (end - start)
        let color = if pocket.focus { "#48d4ab" } else { "#94a3b8" }
        svg = svg +
          "<rect x=\"" +
          x.to_string() +
          "\" y=\"106\" width=\"" +
          w.to_string() +
          "\" height=\"48\" fill=\"" +
          color +
          "\"/>"
      }
      for event in report.events {
        let x = 36 + (event.start - start) * 888 / (end - start)
        let w = (event.end - event.start) * 888 / (end - start)
        svg = svg +
          "<rect x=\"" +
          x.to_string() +
          "\" y=\"106\" width=\"" +
          w.to_string() +
          "\" height=\"48\" fill=\"#f6b56b\"/>"
      }
      svg = svg +
        "<text x=\"36\" y=\"180\" font-size=\"13\">Green: focus | Orange: busy | Light grey: short gap | Dark grey: recovery</text>"
      let mut y = 214
      for event in report.events {
        svg = svg +
          "<text x=\"36\" y=\"" +
          y.to_string() +
          "\" font-size=\"15\">" +
          clock(event.start) +
          " - " +
          clock(event.end) +
          " / " +
          event.id +
          "</text>"
        y = y + 26
      }
      y = y + 12
      for suggestion in report.suggestions {
        svg = svg +
          "<text x=\"36\" y=\"" +
          y.to_string() +
          "\" font-size=\"15\" fill=\"#48d4ab\">Move " +
          suggestion.event_id +
          " out of this day: +" +
          suggestion.gain_minutes.to_string() +
          " focus min</text>"
        y = y + 24
      }
      Ok(svg + "</g></svg>")
    }
  }
}

///|
pub extend Event with ToJson::{to_json}

///|
pub extend Pocket with ToJson::{to_json}

///|
pub extend Summary with ToJson::{to_json}

///|
pub extend Suggestion with ToJson::{to_json}

///|
pub extend Day with ToJson::{to_json}

///|
pub extend Settings with ToJson::{to_json}

///|
pub extend Report with ToJson::{to_json}
