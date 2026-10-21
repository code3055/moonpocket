///|
struct PlanTask {
  id : String
  duration : Int
  release : Int
  deadline : Int
  value : Int
  context : String
  mut requires : Int
} derive(ToJson)

///|
pub(all) struct Assignment {
  task_id : String
  start : String
  end : String
  value : Int
  context : String
} derive(ToJson)

///|
pub(all) struct Unscheduled {
  task_id : String
  reason : String
} derive(ToJson)

///|
pub(all) struct TaskPlan {
  schema_version : Int
  algorithm : String
  optimal : Bool
  objective : String
  total_value : Int
  scheduled_count : Int
  switch_minutes : Int
  states_reached : Int
  transitions_considered : Int
  assignments : Array[Assignment]
  unscheduled : Array[Unscheduled]
} derive(ToJson)

///|
pub extend PlanTask with ToJson::{to_json}

///|
pub extend Assignment with ToJson::{to_json}

///|
pub extend Unscheduled with ToJson::{to_json}

///|
pub extend TaskPlan with ToJson::{to_json}

///|
fn plan_integer(text : String, maximum : Int) -> Int? {
  if text.length() == 0 || text.length() > 6 {
    return None
  }
  let mut n = 0
  for c in text {
    if c < '0' || c > '9' {
      return None
    }
    n = n * 10 + c.to_int() - 48
    if n > maximum {
      return None
    }
  }
  Some(n)
}

///|
fn plan_id(id : String) -> Bool {
  if id.length() == 0 || id.length() > 64 {
    return false
  }
  for c in id {
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
fn task_index(tasks : Array[PlanTask], id : String) -> Int? {
  for i = 0; i < tasks.length(); i = i + 1 {
    if tasks[i].id == id {
      return Some(i)
    }
  }
  None
}

///|
fn parse_tasks(
  text : String,
  day_start : Int,
  day_end : Int,
) -> Result[Array[PlanTask], String] {
  let tasks : Array[PlanTask] = []
  let dependencies : Array[(String, String, Int)] = []
  let rows = words(text)
  for line = 0; line < rows.length(); line = line + 1 {
    let row = rows[line]
    let error = "task line " + (line + 1).to_string() + ": "
    if row.length() == 0 {
      continue
    }
    if row[0] == "after" {
      if row.length() != 3 {
        return Err(error + "expected after CHILD PARENT")
      }
      dependencies.push((row[1], row[2], line + 1))
      if dependencies.length() > 196 {
        return Err(error + "too many dependency declarations")
      }
      continue
    }
    if row[0] != "task" || row.length() != 7 {
      return Err(
        error + "expected task ID DURATION RELEASE DEADLINE VALUE CONTEXT",
      )
    }
    if tasks.length() >= 14 {
      return Err(error + "exact planner supports at most 14 tasks")
    }
    if !plan_id(row[1]) || !plan_id(row[6]) {
      return Err(error + "invalid task identifier or context")
    }
    if task_index(tasks, row[1]) is Some(_) {
      return Err(error + "duplicate task identifier")
    }
    match
      (
        plan_integer(row[2], 1440),
        time(row[3], false),
        time(row[4], true),
        plan_integer(row[5], 10000),
      ) {
      (Some(duration), Some(release), Some(deadline), Some(value)) => {
        if duration < 1 ||
          value < 1 ||
          release < day_start ||
          deadline > day_end ||
          release >= deadline {
          return Err(error + "invalid duration, value or task time window")
        }
        tasks.push({
          id: row[1],
          duration,
          release,
          deadline,
          value,
          context: row[6],
          requires: 0,
        })
      }
      _ => return Err(error + "invalid integer or HH:MM time")
    }
  }
  // Canonical ID order makes equal-score plans independent of input ordering.
  for i = 1; i < tasks.length(); i = i + 1 {
    let mut j = i
    while j > 0 && !id_before(tasks[j - 1].id, tasks[j].id) {
      let a = tasks[j - 1]
      tasks[j - 1] = tasks[j]
      tasks[j] = a
      j = j - 1
    }
  }
  for (child, parent, line) in dependencies {
    match (task_index(tasks, child), task_index(tasks, parent)) {
      (Some(c), Some(p)) => {
        if c == p {
          return Err("task line " + line.to_string() + ": self dependency")
        }
        let bit = 1 << p
        if (tasks[c].requires & bit) != 0 {
          return Err("task line " + line.to_string() + ": duplicate dependency")
        }
        tasks[c].requires = tasks[c].requires | bit
      }
      _ =>
        return Err(
          "task line " + line.to_string() + ": unknown dependency endpoint",
        )
    }
  }
  let mut resolved = 0
  for pass = 0; pass < tasks.length(); pass = pass + 1 {
    for i = 0; i < tasks.length(); i = i + 1 {
      if (tasks[i].requires & resolved) == tasks[i].requires {
        resolved = resolved | (1 << i)
      }
    }
  }
  if resolved != (1 << tasks.length()) - 1 {
    return Err("task dependency cycle detected")
  }
  Ok(tasks)
}

///|
fn task_slot(
  task : PlanTask,
  earliest : Int,
  windows : Array[(Int, Int)],
) -> Int? {
  let ready = if earliest > task.release { earliest } else { task.release }
  for (s, e) in windows {
    let start = if ready > s { ready } else { s }
    if start + task.duration <= e && start + task.duration <= task.deadline {
      return Some(start)
    }
  }
  None
}

///|
fn solve_tasks(
  tasks : Array[PlanTask],
  windows : Array[(Int, Int)],
  start : Int,
  switch_minutes : Int,
) -> TaskPlan {
  let n = tasks.length()
  let states = 1 << n
  let finishes = Array::make(states * n, 2000)
  let parents = Array::make(states * n, -1)
  let starts = Array::make(states * n, -1)
  let values = Array::make(states, 0)
  let counts = Array::make(states, 0)
  let mut reached = 0
  let mut transitions = 0
  for mask = 1; mask < states; mask = mask + 1 {
    for i = 0; i < n; i = i + 1 {
      let bit = 1 << i
      if (mask & bit) != 0 {
        values[mask] = values[mask - bit] + tasks[i].value
        counts[mask] = counts[mask - bit] + 1
        break
      }
    }
  }
  for i = 0; i < n; i = i + 1 {
    if tasks[i].requires != 0 {
      continue
    }
    transitions = transitions + 1
    match task_slot(tasks[i], start, windows) {
      Some(s) => {
        let index = (1 << i) * n + i
        finishes[index] = s + tasks[i].duration
        starts[index] = s
        reached = reached + 1
      }
      None => ()
    }
  }
  let mut best = -1
  let mut best_value = 0
  let mut best_count = 0
  let mut best_finish = start
  for mask = 1; mask < states; mask = mask + 1 {
    for last = 0; last < n; last = last + 1 {
      let state = mask * n + last
      if finishes[state] == 2000 {
        continue
      }
      if values[mask] > best_value ||
        (values[mask] == best_value && counts[mask] > best_count) ||
        (
          values[mask] == best_value &&
          counts[mask] == best_count &&
          finishes[state] < best_finish
        ) {
        best = state
        best_value = values[mask]
        best_count = counts[mask]
        best_finish = finishes[state]
      }
      for next = 0; next < n; next = next + 1 {
        let bit = 1 << next
        if (mask & bit) != 0 ||
          (tasks[next].requires & mask) != tasks[next].requires {
          continue
        }
        transitions = transitions + 1
        let ready = finishes[state] +
          (if tasks[last].context == tasks[next].context {
            0
          } else {
            switch_minutes
          })
        match task_slot(tasks[next], ready, windows) {
          None => ()
          Some(s) => {
            let dest = (mask | bit) * n + next
            let finish = s + tasks[next].duration
            if finish < finishes[dest] {
              if finishes[dest] == 2000 {
                reached = reached + 1
              }
              finishes[dest] = finish
              starts[dest] = s
              parents[dest] = state
            }
          }
        }
      }
    }
  }
  let selected = if best < 0 { 0 } else { best / n }
  let reversed : Array[Assignment] = []
  let mut cursor = best
  while cursor >= 0 {
    let i = cursor % n
    reversed.push({
      task_id: tasks[i].id,
      start: clock(starts[cursor]),
      end: clock(finishes[cursor]),
      value: tasks[i].value,
      context: tasks[i].context,
    })
    cursor = parents[cursor]
  }
  let assignments : Array[Assignment] = []
  let mut i = reversed.length() - 1
  while i >= 0 {
    assignments.push(reversed[i])
    i = i - 1
  }
  let unscheduled : Array[Unscheduled] = []
  for i = 0; i < n; i = i + 1 {
    if (selected & (1 << i)) != 0 {
      continue
    }
    let reason = if task_slot(tasks[i], start, windows) is None {
      "no_contiguous_window"
    } else if (tasks[i].requires & selected) != tasks[i].requires {
      "prerequisite_not_scheduled"
    } else {
      "not_selected_by_optimal_objective"
    }
    unscheduled.push({ task_id: tasks[i].id, reason, })
  }
  {
    schema_version: 1,
    algorithm: "subset_dp_earliest_finish",
    optimal: true,
    objective: "max_value_then_count_then_earliest_finish",
    total_value: best_value,
    scheduled_count: best_count,
    switch_minutes,
    states_reached: reached,
    transitions_considered: transitions,
    assignments,
    unscheduled,
  }
}

///|
pub fn plan_schedule(
  day_text : String,
  task_text : String,
  recovery : Int,
  switch_minutes : Int,
) -> Result[TaskPlan, String] {
  if recovery < 0 ||
    recovery > 1440 ||
    switch_minutes < 0 ||
    switch_minutes > 1440 {
    return Err("recovery and switch minutes must be 0..1440")
  }
  match parse(day_text) {
    Err(e) => Err(e)
    Ok((start, end, events)) =>
      match parse_tasks(task_text, start, end) {
        Err(e) => Err(e)
        Ok(tasks) => {
          let (_, pockets) = calculate(start, end, events, 1, recovery, "")
          let windows : Array[(Int, Int)] = []
          for p in pockets {
            if p.usable_minutes > 0 {
              windows.push(
                (
                  time(p.usable_start, true).unwrap(),
                  time(p.end, true).unwrap(),
                ),
              )
            }
          }
          Ok(solve_tasks(tasks, windows, start, switch_minutes))
        }
      }
  }
}

///|
pub fn plan_from_text(
  day_text : String,
  task_text : String,
  recovery : Int,
  switch_minutes : Int,
) -> Result[String, String] {
  match plan_schedule(day_text, task_text, recovery, switch_minutes) {
    Err(error) => Err(error)
    Ok(plan) => Ok(@json.to_json(plan).stringify())
  }
}
