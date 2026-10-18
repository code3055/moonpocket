///|
fn calendar_date(date : String) -> String? {
  let c = date.iter().to_array()
  if c.length() != 10 || c[4] != '-' || c[7] != '-' {
    return None
  }
  let mut digits = ""
  for i = 0; i < c.length(); i = i + 1 {
    if i == 4 || i == 7 {
      continue
    }
    if c[i] < '0' || c[i] > '9' {
      return None
    }
    digits = digits + c[i].to_string()
  }
  let year = (c[0].to_int() - 48) * 1000 +
    (c[1].to_int() - 48) * 100 +
    (c[2].to_int() - 48) * 10 +
    c[3].to_int() -
    48
  let month = (c[5].to_int() - 48) * 10 + c[6].to_int() - 48
  let day = (c[8].to_int() - 48) * 10 + c[9].to_int() - 48
  if year < 1 || year > 9998 || month < 1 || month > 12 {
    return None
  }
  let leap = year % 400 == 0 || (year % 4 == 0 && year % 100 != 0)
  let days = if month == 2 {
    if leap {
      29
    } else {
      28
    }
  } else if month == 4 || month == 6 || month == 9 || month == 11 {
    30
  } else {
    31
  }
  if day < 1 || day > days {
    None
  } else {
    Some(digits)
  }
}

///|
fn calendar_next(date : String) -> String {
  let c = date.iter().to_array()
  let mut year = (c[0].to_int() - 48) * 1000 +
    (c[1].to_int() - 48) * 100 +
    (c[2].to_int() - 48) * 10 +
    c[3].to_int() -
    48
  let mut month = (c[5].to_int() - 48) * 10 + c[6].to_int() - 48
  let mut day = (c[8].to_int() - 48) * 10 + c[9].to_int() - 48
  let leap = year % 400 == 0 || (year % 4 == 0 && year % 100 != 0)
  let days = if month == 2 {
    if leap {
      29
    } else {
      28
    }
  } else if month == 4 || month == 6 || month == 9 || month == 11 {
    30
  } else {
    31
  }
  day = day + 1
  if day > days {
    day = 1
    month = month + 1
  }
  if month > 12 {
    month = 1
    year = year + 1
  }
  let mut year_text = year.to_string()
  while year_text.length() < 4 {
    year_text = "0" + year_text
  }
  year_text + pad(month) + pad(day)
}

///|
fn calendar_time(date : String, day : String, clock_text : String) -> String {
  if clock_text == "24:00" {
    calendar_next(day) + "T000000"
  } else {
    let c = clock_text.iter().to_array()
    date +
    "T" +
    c[0].to_string() +
    c[1].to_string() +
    c[3].to_string() +
    c[4].to_string() +
    "00"
  }
}

///|
pub fn calendar_from_text(
  text : String,
  min_focus : Int,
  recovery : Int,
  date : String,
) -> Result[String, String] {
  let compact = match calendar_date(date) {
    Some(s) => s
    None => return Err("date must be a valid YYYY-MM-DD (years 0001..9998)")
  }
  match analyze(text, min_focus, recovery) {
    Err(e) => Err(e)
    Ok(r) => {
      let mut out = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//MoonPocket//Focus Pockets//EN\r\nCALSCALE:GREGORIAN\r\n"
      let mut index = 0
      for p in r.pockets {
        if !p.focus {
          continue
        }
        index = index + 1
        let start = calendar_time(compact, date, p.usable_start)
        let end = calendar_time(compact, date, p.end)
        // Floating times follow the calendar client's local timezone.
        out = out +
          "BEGIN:VEVENT\r\nUID:" +
          compact +
          "-" +
          index.to_string() +
          "-" +
          min_focus.to_string() +
          "-" +
          recovery.to_string() +
          "@moonpocket\r\nDTSTAMP:" +
          compact +
          "T000000Z\r\nDTSTART:" +
          start +
          "\r\nDTEND:" +
          end +
          "\r\nSUMMARY:MoonPocket focus\r\nDESCRIPTION:Planned focus pocket. Confirm before importing.\r\nEND:VEVENT\r\n"
      }
      Ok(out + "END:VCALENDAR\r\n")
    }
  }
}
