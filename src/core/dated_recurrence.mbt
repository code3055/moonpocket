///|
/// A calendar-labeled expansion with an explicit fixed-offset timezone.
pub(all) struct DatedDay {
  date : String
  utc_date : String
  timezone_minutes : Int
  skipped : Bool
  text : String
} derive(ToJson)

///|
fn date_digits(text : String, start : Int, length : Int) -> Int? {
  let chars = text.iter().to_array()
  if start + length > chars.length() {
    return None
  }
  let mut value = 0
  for i = start; i < start + length; i = i + 1 {
    if chars[i] < '0' || chars[i] > '9' {
      return None
    }
    value = value * 10 + chars[i].to_int() - 48
  }
  Some(value)
}

///|
fn leap_year(year : Int) -> Bool {
  year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

///|
fn month_days(year : Int, month : Int) -> Int {
  if month == 2 {
    if leap_year(year) {
      29
    } else {
      28
    }
  } else if month == 4 || month == 6 || month == 9 || month == 11 {
    30
  } else {
    31
  }
}

///|
fn parse_date(text : String) -> (Int, Int, Int)? {
  if text.length() != 10 || text[4] != '-' || text[7] != '-' {
    return None
  }
  match
    (date_digits(text, 0, 4), date_digits(text, 5, 2), date_digits(text, 8, 2)) {
    (Some(y), Some(m), Some(d)) if y >= 1 &&
      y <= 9998 &&
      m >= 1 &&
      m <= 12 &&
      d >= 1 &&
      d <= month_days(y, m) => Some((y, m, d))
    _ => None
  }
}

///|
fn date_text(year : Int, month : Int, day : Int) -> String {
  let pad = fn(n : Int) {
    if n < 10 {
      "0" + n.to_string()
    } else {
      n.to_string()
    }
  }
  let y = if year < 1000 { "0" + year.to_string() } else { year.to_string() }
  y + "-" + pad(month) + "-" + pad(day)
}

///|
fn shift_date(year : Int, month : Int, day : Int, delta : Int) -> String {
  let mut y = year
  let mut m = month
  let mut d = day
  let mut remaining = delta
  while remaining > 0 {
    d = d + 1
    if d > month_days(y, m) {
      d = 1
      m = m + 1
      if m > 12 {
        m = 1
        y = y + 1
      }
    }
    remaining = remaining - 1
  }
  while remaining < 0 {
    d = d - 1
    if d < 1 {
      m = m - 1
      if m < 1 {
        m = 12
        y = y - 1
      }
      d = month_days(y, m)
    }
    remaining = remaining + 1
  }
  date_text(y, m, d)
}

///|
/// Expand a recurrence into dated days. `timezone_minutes` is the local offset
/// from UTC; exceptions contain exact local dates to skip.
pub fn expand_dated_recurrence(
  text : String,
  start_date : String,
  days : Int,
  timezone_minutes : Int,
  exceptions : Array[String],
) -> Result[Array[DatedDay], String] {
  if timezone_minutes < -840 || timezone_minutes > 840 || days < 1 || days > 366 {
    return Err("days must be 1..366 and timezone must be -840..840")
  }
  let (year, month, day) = match parse_date(start_date) {
    Some(value) => value
    None => return Err("invalid YYYY-MM-DD start date")
  }
  let expanded = match expand_recurrence(text, days) {
    Ok(value) => value
    Err(e) => return Err(e)
  }
  let result : Array[DatedDay] = []
  for item in expanded {
    let date = shift_date(year, month, day, item.day_index)
    let skipped = exceptions.contains(date)
    let utc_date = if timezone_minutes > 0 {
      shift_date(year, month, day, item.day_index - 1)
    } else {
      date
    }
    result.push({
      date,
      utc_date,
      timezone_minutes,
      skipped,
      text: if skipped {
        ""
      } else {
        item.text
      },
    })
  }
  Ok(result)
}

///|
pub extend DatedDay with ToJson::{to_json}
