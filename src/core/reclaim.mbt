///|
pub(all) struct ReclaimPlan {
  cost : Int
  removed_ids : Array[String]
  focus_minutes : Int
  largest_focus : Int
} derive(ToJson)

///|
pub(all) struct ReclaimDiagnostics {
  movable_events : Int
  total_subsets : Int
  evaluated_subsets : Int
  budget_pruned_subsets : Int
  algorithm : String
  reason : String
} derive(ToJson)

///|
pub(all) struct ReclaimReport {
  schema_version : Int
  status : String
  optimal : Bool
  target_minutes : Int
  budget : Int
  baseline_focus : Int
  best_focus_under_budget : Int
  target_shortfall_minutes : Int
  solution : ReclaimPlan?
  frontier : Array[ReclaimPlan]
  diagnostics : ReclaimDiagnostics
} derive(ToJson)

///|
fn reclaim_positive_int(text : String) -> Int? {
  if text.length() == 0 {
    return None
  }
  let mut value = 0
  for c in text {
    if c < '0' || c > '9' {
      return None
    }
    value = value * 10 + c.to_int() - 48
    // Bound during parsing so an arbitrarily long number cannot overflow.
    if value > 10000 {
      return None
    }
  }
  if value == 0 {
    None
  } else {
    Some(value)
  }
}

///|
fn reclaim_preferred(a : ReclaimPlan, b : ReclaimPlan) -> Bool {
  if a.focus_minutes != b.focus_minutes {
    return a.focus_minutes > b.focus_minutes
  }
  if a.removed_ids.length() != b.removed_ids.length() {
    return a.removed_ids.length() < b.removed_ids.length()
  }
  for i = 0; i < a.removed_ids.length(); i = i + 1 {
    if a.removed_ids[i] != b.removed_ids[i] {
      return id_before(a.removed_ids[i], b.removed_ids[i])
    }
  }
  false
}

///|
fn reclaim(
  text : String,
  min_focus : Int,
  recovery : Int,
  target : Int,
  budget : Int,
  cost_text : String,
) -> Result[ReclaimReport, String] {
  if min_focus < 1 || min_focus > 1440 || recovery < 0 || recovery > 1440 {
    return Err("min_focus must be 1..1440; recovery must be 0..1440")
  }
  if target < 1 || target > 1440 || budget < 0 || budget > 160000 {
    return Err("target must be 1..1440; budget must be 0..160000")
  }
  let (start, end, events) = match parse(text) {
    Err(e) => return Err(e)
    Ok(value) => value
  }
  let movable : Array[Event] = []
  for event in events {
    if !event.fixed {
      movable.push(event)
    }
  }
  if movable.length() > 16 {
    return Err("exact reclaim supports at most 16 movable events")
  }
  // IDs, rather than input order or timestamps, define tie-breaking.
  for i = 1; i < movable.length(); i = i + 1 {
    let mut j = i
    while j > 0 && !id_before(movable[j - 1].id, movable[j].id) {
      let previous = movable[j - 1]
      movable[j - 1] = movable[j]
      movable[j] = previous
      j = j - 1
    }
  }
  let costs = Array::make(movable.length(), 1)
  let assigned = Array::make(movable.length(), false)
  let rows = words(cost_text)
  for line = 0; line < rows.length(); line = line + 1 {
    let row = rows[line]
    if row.length() == 0 {
      continue
    }
    let prefix = "cost line " + (line + 1).to_string() + ": "
    if row.length() != 3 || row[0] != "cost" {
      return Err(prefix + "expected cost EVENT_ID POSITIVE_INT")
    }
    let value = match reclaim_positive_int(row[2]) {
      None => return Err(prefix + "cost must be 1..10000")
      Some(value) => value
    }
    let mut found = false
    for i = 0; i < movable.length(); i = i + 1 {
      if movable[i].id == row[1] {
        if assigned[i] {
          return Err(prefix + "duplicate cost identifier")
        }
        costs[i] = value
        assigned[i] = true
        found = true
      }
    }
    if !found {
      return Err(prefix + "unknown or fixed event identifier: " + row[1])
    }
  }
  let powers : Array[Int] = []
  let mut total = 1
  for _event in movable {
    powers.push(total)
    total = total * 2
  }
  let (baseline, _) = calculate(start, end, events, min_focus, recovery, "")
  let best_by_cost : Array[ReclaimPlan?] = Array::make(budget + 1, None)
  let subset_cost = Array::make(total, 0)
  let mut evaluated = 0
  let mut pruned = 0
  // Every in-budget subset is evaluated independently. The proof uses only
  // positive costs and never assumes monotonicity of a focus objective.
  for mask = 0; mask < total; mask = mask + 1 {
    if mask > 0 {
      for i = 0; i < powers.length(); i = i + 1 {
        if mask / powers[i] % 2 == 1 {
          subset_cost[mask] = subset_cost[mask - powers[i]] + costs[i]
          break
        }
      }
    }
    let cost = subset_cost[mask]
    if cost > budget {
      pruned = pruned + 1
      continue
    }
    evaluated = evaluated + 1
    let removed_ids : Array[String] = []
    for i = 0; i < movable.length(); i = i + 1 {
      if mask / powers[i] % 2 == 1 {
        removed_ids.push(movable[i].id)
      }
    }
    let kept : Array[Event] = []
    for event in events {
      let mut removed = false
      for id in removed_ids {
        if id == event.id {
          removed = true
          break
        }
      }
      if !removed {
        kept.push(event)
      }
    }
    let (summary, _) = calculate(start, end, kept, min_focus, recovery, "")
    let plan : ReclaimPlan = {
      cost,
      removed_ids,
      focus_minutes: summary.focus_minutes,
      largest_focus: summary.largest_focus,
    }
    match best_by_cost[cost] {
      None => best_by_cost[cost] = Some(plan)
      Some(previous) =>
        if reclaim_preferred(plan, previous) {
          best_by_cost[cost] = Some(plan)
        }
    }
  }
  let frontier : Array[ReclaimPlan] = []
  let mut best_focus = -1
  let mut solution : ReclaimPlan? = None
  for cost = 0; cost <= budget; cost = cost + 1 {
    if best_by_cost[cost] is Some(plan) {
      // A cost-focus point is dominated if a cheaper point has equal or
      // greater focus. One deterministic representative remains per point.
      if plan.focus_minutes > best_focus {
        frontier.push(plan)
        best_focus = plan.focus_minutes
      }
      if solution is None && plan.focus_minutes >= target {
        solution = Some(plan)
      }
    }
  }
  Ok({
    schema_version: 1,
    status: if solution is Some(_) {
      "feasible"
    } else {
      "infeasible"
    },
    optimal: true,
    target_minutes: target,
    budget,
    baseline_focus: baseline.focus_minutes,
    best_focus_under_budget: best_focus,
    target_shortfall_minutes: if target > best_focus {
      target - best_focus
    } else {
      0
    },
    solution,
    frontier,
    diagnostics: {
      movable_events: movable.length(),
      total_subsets: total,
      evaluated_subsets: evaluated,
      budget_pruned_subsets: pruned,
      algorithm: "exact-budgeted-subset-enumeration",
      reason: if solution is Some(_) {
        "target_reached"
      } else {
        "no_subset_within_budget_reaches_target"
      },
    },
  })
}

///|
pub fn reclaim_schedule(
  text : String,
  min_focus : Int,
  recovery : Int,
  target : Int,
  budget : Int,
  cost_text : String,
) -> Result[ReclaimReport, String] {
  reclaim(text, min_focus, recovery, target, budget, cost_text)
}

///|
pub fn reclaim_from_text(
  text : String,
  min_focus : Int,
  recovery : Int,
  target : Int,
  budget : Int,
  cost_text : String,
) -> Result[String, String] {
  match reclaim(text, min_focus, recovery, target, budget, cost_text) {
    Err(error) => Err(error)
    Ok(report) => Ok(@json.to_json(report).stringify())
  }
}

///|
pub extend ReclaimPlan with ToJson::{to_json}

///|
pub extend ReclaimDiagnostics with ToJson::{to_json}

///|
pub extend ReclaimReport with ToJson::{to_json}
