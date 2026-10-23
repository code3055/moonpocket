///|
/// One task placed on a concurrent resource timeline.
pub(all) struct ParallelAssignment {
  task_id : String
  start : String
  end : String
  resource : String
  value : Int
} derive(ToJson)

///|
/// Deterministic capacity-aware schedule produced by the parallel solver.
pub(all) struct ParallelPlan {
  algorithm : String
  scheduled_count : Int
  total_value : Int
  capacity_constraints : Int
  assignments : Array[ParallelAssignment]
  unscheduled : Array[Unscheduled]
} derive(ToJson)

///|
fn capacity_value(text : String) -> Int? {
  if text.length() == 0 {
    return None
  }
  let mut value = 0
  for c in text {
    if c < '0' || c > '9' {
      return None
    }
    value = value * 10 + c.to_int() - 48
    if value > 64 {
      return None
    }
  }
  if value < 1 {
    None
  } else {
    Some(value)
  }
}

///|
fn capacity_for(name : String, rows : Array[Array[String]]) -> Int {
  if name == "general" {
    return 1000
  }
  for row in rows {
    if row.length() == 3 && row[0] == "capacity" && row[1] == name {
      match capacity_value(row[2]) {
        Some(value) => return value
        None => ()
      }
    }
  }
  1
}

///|
fn parallel_window(
  start : Int,
  finish : Int,
  windows : Array[(Int, Int)],
) -> Bool {
  for (s, e) in windows {
    if start >= s && finish <= e {
      return true
    }
  }
  false
}

///|
fn parallel_conflict(
  resource : String,
  start : Int,
  finish : Int,
  assignments : Array[(String, Int, Int)],
  capacity : Int,
) -> Bool {
  let mut overlapping = 0
  for (name, s, e) in assignments {
    if name == resource && s < finish && start < e {
      overlapping = overlapping + 1
    }
  }
  overlapping >= capacity
}

///|
/// Schedule independent tasks concurrently while respecting resource capacity.
/// This is a deterministic feasible scheduler; `plan_schedule` remains the
/// exact single-worker optimizer for value/count/finish objectives.
pub fn parallel_schedule(
  day_text : String,
  task_text : String,
  capacity_text : String,
  recovery : Int,
) -> Result[ParallelPlan, String] {
  if recovery < 0 || recovery > 1440 {
    return Err("recovery must be 0..1440")
  }
  match parse(day_text) {
    Err(e) => Err(e)
    Ok((day_start, day_end, events)) =>
      match parse_tasks(task_text, day_start, day_end) {
        Err(e) => Err(e)
        Ok((tasks, _resources)) => {
          let (_, pockets) = calculate(
            day_start, day_end, events, 1, recovery, "",
          )
          let windows : Array[(Int, Int)] = []
          for pocket in pockets {
            if pocket.usable_minutes > 0 {
              windows.push(
                (
                  time(pocket.usable_start, true).unwrap(),
                  time(pocket.end, true).unwrap(),
                ),
              )
            }
          }
          let capacity_rows = words(capacity_text)
          for row in capacity_rows {
            if row.length() != 3 ||
              row[0] != "capacity" ||
              !plan_id(row[1]) ||
              capacity_value(row[2]) is None {
              return Err("capacity line must be capacity RESOURCE POSITIVE_INT")
            }
          }
          let assigned : Array[(String, Int, Int)] = []
          let result : Array[ParallelAssignment] = []
          let done = Array::make(tasks.length(), false)
          let mut progress = true
          while progress {
            progress = false
            for i = 0; i < tasks.length(); i = i + 1 {
              if done[i] {
                continue
              }
              let task = tasks[i]
              let mut ready = task.release
              let mut dependencies_ready = true
              for parent = 0; parent < tasks.length(); parent = parent + 1 {
                if (task.requires & (1 << parent)) != 0 {
                  if !done[parent] {
                    dependencies_ready = false
                  }
                  for assignment in result {
                    if assignment.task_id == tasks[parent].id {
                      let finish = time(assignment.end, true).unwrap()
                      if finish > ready {
                        ready = finish
                      }
                    }
                  }
                }
              }
              if !dependencies_ready {
                continue
              }
              let cap = capacity_for(task.resource, capacity_rows)
              let mut found : Int? = None
              let mut start = ready
              while start + task.duration <= task.deadline {
                let finish = start + task.duration
                if parallel_window(start, finish, windows) &&
                  !parallel_conflict(
                    task.resource,
                    start,
                    finish,
                    assigned,
                    cap,
                  ) {
                  found = Some(start)
                  break
                }
                start = start + 1
              }
              match found {
                None => ()
                Some(start) => {
                  let finish = start + task.duration
                  assigned.push((task.resource, start, finish))
                  result.push({
                    task_id: task.id,
                    start: clock(start),
                    end: clock(finish),
                    resource: task.resource,
                    value: task.value,
                  })
                  done[i] = true
                  progress = true
                }
              }
            }
          }
          let mut total = 0
          let mut count = 0
          for assignment in result {
            total = total + assignment.value
            count = count + 1
          }
          let unscheduled : Array[Unscheduled] = []
          for i = 0; i < tasks.length(); i = i + 1 {
            if !done[i] {
              unscheduled.push({
                task_id: tasks[i].id,
                reason: "capacity_or_window_unavailable",
              })
            }
          }
          Ok({
            algorithm: "greedy_parallel_capacity",
            scheduled_count: count,
            total_value: total,
            capacity_constraints: capacity_rows.length(),
            assignments: result,
            unscheduled,
          })
        }
      }
  }
}

///|
pub extend ParallelAssignment with ToJson::{to_json}

///|
pub extend ParallelPlan with ToJson::{to_json}
