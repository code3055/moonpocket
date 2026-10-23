///|
extern "js" fn read_file(path : String) -> String? =
  #| function(path) { try { return require('node:fs').readFileSync(path === '-' ? 0 : path, 'utf8'); } catch (_) { return undefined; } }

///|
extern "js" fn write_file(path : String, content : String) -> Bool =
  #| function(path, content) { try { require('node:fs').writeFileSync(path, content, 'utf8'); return true; } catch (_) { return false; } }

///|
extern "js" fn fail(message : String, code : Int) -> Unit =
  #| function(message, code) { console.error(message); process.exitCode = code; }

///|
extern "js" fn meets_gate(report : String, minimum : Int) -> Bool =
  #| function(report, minimum) { return JSON.parse(report).summary.focus_minutes >= minimum; }

///|
extern "js" fn reclaim_feasible(report : String) -> Bool =
  #| function(report) { return JSON.parse(report).status === 'feasible'; }

///|
extern "js" fn paths_safe(
  input : String,
  report : String,
  svg : String,
) -> Bool =
  #| function(input, report, svg) {
  #|   const fs = require('node:fs'), path = require('node:path');
  #|   try {
  #|     const canonical = p => { const absolute = path.resolve(p); const resolved = fs.existsSync(absolute) ? fs.realpathSync(absolute) : absolute; return process.platform === 'win32' ? resolved.toLowerCase() : resolved; };
  #|     const paths = [input === '-' ? '' : input, report, svg].filter(p => p !== '').map(canonical);
  #|     return new Set(paths).size === paths.length;
  #|   } catch (_) { return false; }
  #| }

///|
fn bounded_number(text : String, maximum : Int) -> Int? {
  if text.length() == 0 || text.length() > 6 {
    return None
  }
  let mut n = 0
  for c in text {
    if c < '0' || c > '9' {
      return None
    }
    n = n * 10 + c.to_int() - 48
  }
  if n > maximum {
    None
  } else {
    Some(n)
  }
}

///|
fn number(text : String) -> Int? {
  bounded_number(text, 1440)
}

///|
fn run() -> Unit {
  let args = @env.args()
  let mut input = ""
  let mut report_path = ""
  let mut svg_path = ""
  let mut markdown_path = ""
  let mut calendar_path = ""
  let mut date = ""
  let mut task_path = ""
  let mut cost_path = ""
  let mut mode = "audit"
  let mut target = 0
  let mut budget = 16
  let mut switching = 0
  let mut strategy = "value"
  let mut min_focus = 45
  let mut recovery = 10
  let mut required = 0
  let mut i = 2
  while i < args.length() {
    let key = args[i]
    if key == "--help" || key == "-h" {
      println(
        "MoonPocket — find real focus pockets and simulate reclaiming time\n--input <file>       day snapshot (default: built-in example)\n--report <file>      JSON report (also printed to stdout)\n--svg <file>         annotated timeline\n--min-focus <n>      minimum usable pocket minutes (default 45)\n--recovery <n>       recovery after busy blocks (default 10)\n--require-focus <n>  exit 1 when total focus minutes fall below n\n--markdown <file>    readable focus report\n--input -            read stdin\n--ics <file>         export local-time focus calendar\n--date <YYYY-MM-DD>  required for calendar export\n--mode <audit|plan|reclaim>  solver mode (default: audit)\n--tasks <file>       task definitions for plan mode\n--costs <file>       per-event costs for reclaim mode\n--target <n>         target focus minutes for reclaim mode\n--budget <n>         maximum adjustment cost (default: 16)\n--switch <n>         context switch minutes for plan mode\nExit codes: 0 success, 1 focus gate unmet, 2 input/options/I/O error",
      )
      return
    }
    if i + 1 >= args.length() {
      fail("Missing value for " + key, 2)
      return
    }
    let value = args[i + 1]
    match key {
      "--input" => input = value
      "--report" => report_path = value
      "--svg" => svg_path = value
      "--markdown" => markdown_path = value
      "--ics" => calendar_path = value
      "--date" => date = value
      "--mode" => mode = value
      "--tasks" => task_path = value
      "--costs" => cost_path = value
      "--strategy" => strategy = value
      "--target" | "--switch" =>
        match number(value) {
          None => {
            fail("Expected integer 0..1440 for " + key, 2)
            return
          }
          Some(n) => if key == "--target" { target = n } else { switching = n }
        }
      "--budget" =>
        match bounded_number(value, 160000) {
          None => {
            fail("Expected integer 0..160000 for --budget", 2)
            return
          }
          Some(n) => budget = n
        }
      "--min-focus" | "--recovery" | "--require-focus" =>
        match number(value) {
          None => {
            fail("Expected integer 0..1440 for " + key, 2)
            return
          }
          Some(n) =>
            if key == "--min-focus" {
              min_focus = n
            } else if key == "--recovery" {
              recovery = n
            } else {
              required = n
            }
        }
      _ => {
        fail("Unknown option: " + key, 2)
        return
      }
    }
    i = i + 2
  }
  if !paths_safe(input, report_path, svg_path) ||
    !paths_safe(input, markdown_path, report_path) ||
    !paths_safe("", markdown_path, svg_path) {
    fail("Input and output paths must be different", 2)
    return
  }
  let text = if input == "" {
    "day 09:00 18:00\nbusy standup 09:30 10:00\nbusy review 10:45 11:15\nbusy lunch 12:00 13:00\nbusy sync 14:00 14:30\nbusy checkin 15:15 15:30\nbusy wrapup 17:00 17:30\n"
  } else {
    match read_file(input) {
      Some(content) => content
      None => {
        fail("Cannot read input: " + input, 2)
        return
      }
    }
  }
  if mode != "audit" {
    if mode != "plan" && mode != "reclaim" {
      fail("--mode must be audit, plan or reclaim", 2)
      return
    }
    if svg_path != "" ||
      markdown_path != "" ||
      calendar_path != "" ||
      date != "" ||
      required != 0 {
      fail(
        "Audit exports and --require-focus cannot be used in solver modes", 2,
      )
      return
    }
    if !paths_safe(task_path, report_path, input) ||
      !paths_safe(cost_path, report_path, "") {
      fail("Solver input and report paths must be different", 2)
      return
    }
    let extra_path = if mode == "plan" { task_path } else { cost_path }
    if mode == "plan" && (task_path == "" || cost_path != "" || target != 0) {
      fail("Plan mode requires --tasks and does not accept reclaim options", 2)
      return
    }
    if mode == "reclaim" && (task_path != "" || switching != 0) {
      fail("Reclaim mode does not accept task options", 2)
      return
    }
    if mode == "reclaim" && strategy != "value" {
      fail("--strategy requires plan mode", 2)
      return
    }
    if extra_path == "-" && input == "-" {
      fail("Only one input may read stdin", 2)
      return
    }
    let extra = if extra_path == "" {
      ""
    } else {
      match read_file(extra_path) {
        Some(s) => s
        None => {
          fail("Cannot read solver input: " + extra_path, 2)
          return
        }
      }
    }
    let result = if mode == "plan" {
      @core.plan_from_text_with_strategy(
        text, extra, recovery, switching, strategy,
      )
    } else {
      @core.reclaim_from_text(text, min_focus, recovery, target, budget, extra)
    }
    match result {
      Err(e) => fail(e, 2)
      Ok(report) => {
        if report_path != "" && !write_file(report_path, report + "\n") {
          fail("Cannot write report: " + report_path, 2)
          return
        }
        println(report)
        if mode == "reclaim" && !reclaim_feasible(report) {
          fail("Target is infeasible under the adjustment budget", 1)
        }
      }
    }
    return
  }
  if task_path != "" ||
    cost_path != "" ||
    target != 0 ||
    switching != 0 ||
    strategy != "value" {
    fail("Use --mode plan or --mode reclaim for solver options", 2)
    return
  }
  let calendar = if calendar_path != "" {
    if mode != "audit" {
      fail("Calendar export requires audit mode", 2)
      return
    }
    if !paths_safe(input, calendar_path, report_path) ||
      !paths_safe("", calendar_path, svg_path) ||
      !paths_safe("", calendar_path, markdown_path) {
      fail("Input and output paths must be different", 2)
      return
    }
    match @core.calendar_from_text(text, min_focus, recovery, date) {
      Ok(s) => s
      Err(e) => {
        fail(e, 2)
        return
      }
    }
  } else {
    if date != "" {
      fail("--date requires --ics", 2)
      return
    }
    ""
  }
  match @core.analyze_text(text, min_focus, recovery) {
    Err(message) => fail(message, 2)
    Ok(report) => {
      if report_path != "" && !write_file(report_path, report + "\n") {
        fail("Cannot write report: " + report_path, 2)
        return
      }
      if svg_path != "" {
        match @core.svg_from_text(text, min_focus, recovery) {
          Err(message) => {
            fail(message, 2)
            return
          }
          Ok(svg) =>
            if !write_file(svg_path, svg) {
              fail("Cannot write SVG: " + svg_path, 2)
              return
            }
        }
      }
      println(report)
      if calendar_path != "" && !write_file(calendar_path, calendar) {
        fail("Cannot write calendar: " + calendar_path, 2)
        return
      }
      if markdown_path != "" {
        match @core.markdown_from_text(text, min_focus, recovery) {
          Err(e) => {
            fail(e, 2)
            return
          }
          Ok(md) =>
            if !write_file(markdown_path, md) {
              fail("Cannot write Markdown: " + markdown_path, 2)
              return
            }
        }
      }
      if !meets_gate(report, required) {
        fail("Focus budget below --require-focus threshold", 1)
      }
    }
  }
}

///|
fn main {
  run()
}
