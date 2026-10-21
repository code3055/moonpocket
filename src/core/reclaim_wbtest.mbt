///|
test "joint reclaim solves overlap synergy that individual suggestions miss" {
  let snapshot = "day 09:00 12:00\nbusy a 09:30 10:30\nbusy b 09:30 10:30"
  let report = reclaim(snapshot, 45, 10, 150, 2, "").unwrap()
  assert_eq(report.baseline_focus, 80)
  assert_eq(report.solution.unwrap().removed_ids, ["a", "b"])
  assert_eq(report.solution.unwrap().cost, 2)
  assert_eq(report.solution.unwrap().focus_minutes, 180)
  assert_eq(report.frontier.length(), 2)
  assert_eq(report.frontier[0].cost, 0)
  assert_eq(report.frontier[1].cost, 2)
  assert_eq(report.diagnostics.evaluated_subsets, 4)
  assert_eq(reclaim(snapshot, 45, 10, 150, 1, "").unwrap().status, "infeasible")
}

///|
test "fixed events and insufficient budget yield exact infeasibility" {
  let snapshot = "day 09:00 12:00\nfixed meeting 09:00 12:00\nbusy a 10:00 11:00"
  let report = reclaim(snapshot, 30, 10, 1, 100, "").unwrap()
  assert_eq(report.status, "infeasible")
  assert_eq(report.optimal, true)
  assert_true(report.solution is None)
  assert_eq(report.best_focus_under_budget, 0)
  assert_eq(report.frontier.length(), 1)
  assert_eq(report.frontier[0].cost, 0)
}

///|
test "custom costs determine feasibility and deterministic equal-cost tie breaks" {
  let snapshot = "day 09:00 12:00\nbusy b 11:30 12:00\nbusy a 09:00 09:30"
  let report = reclaim(snapshot, 30, 0, 150, 1, "").unwrap()
  assert_eq(report.solution.unwrap().removed_ids, ["a"])
  let weighted = reclaim(snapshot, 30, 0, 150, 1, "cost a 2").unwrap()
  assert_eq(weighted.solution.unwrap().removed_ids, ["b"])
  let fewer = reclaim(
    "day 09:00 12:00\nbusy a 09:00 10:00\nbusy b 10:00 10:30\nbusy c 10:30 11:00",
    1, 0, 120, 2, "cost a 2",
  ).unwrap()
  assert_eq(fewer.solution.unwrap().removed_ids, ["a"])
  // Focus is the first tie-break at the minimum feasible cost.
  let more_focus = reclaim(
    "day 09:00 12:00\nbusy a 09:00 09:30\nbusy b 11:00 12:00", 1, 0, 100, 1, "",
  ).unwrap()
  assert_eq(more_focus.solution.unwrap().removed_ids, ["b"])
}

///|
test "baseline may already reach target and ordering does not change reports" {
  let a = "day 09:00 12:00\nbusy b 11:30 12:00\nbusy a 09:00 09:30"
  let b = "day 09:00 12:00\nbusy a 09:00 09:30\nbusy b 11:30 12:00"
  assert_eq(
    reclaim_from_text(a, 30, 0, 150, 2, "").unwrap(),
    reclaim_from_text(b, 30, 0, 150, 2, "").unwrap(),
  )
  let baseline = reclaim(a, 30, 0, 100, 0, "").unwrap()
  assert_eq(baseline.solution.unwrap().removed_ids, [])
  assert_eq(baseline.solution.unwrap().cost, 0)
  assert_eq(baseline.diagnostics.budget_pruned_subsets, 3)
}

///|
test "strict reclaim constraints reject malformed costs and unsafe search sizes" {
  let snapshot = "day 09:00 12:00\nbusy a 09:00 10:00\nfixed b 10:00 11:00"
  for
    costs in [
      "cost a 0", "cost a -1", "cost a 10001", "cost a 999999999999999999999", "cost a 1.5",
      "cost a 1\ncost a 2", "cost missing 2", "cost b 1", "cost a", "weight a 1",
    ] {
    assert_true(reclaim(snapshot, 30, 0, 100, 2, costs) is Err(_))
  }
  for
    (minimum, recovery, target, budget) in [
      (0, 0, 1, 0),
      (30, -1, 1, 0),
      (30, 0, 0, 0),
      (30, 0, 1441, 0),
      (30, 0, 1, -1),
      (30, 0, 1, 160001),
    ] {
    assert_true(
      reclaim(snapshot, minimum, recovery, target, budget, "") is Err(_),
    )
  }
  let mut too_many = "day 09:00 12:00"
  for i = 0; i < 17; i = i + 1 {
    too_many = too_many + "\nbusy e" + i.to_string() + " 09:00 10:00"
  }
  assert_true(reclaim(too_many, 30, 0, 1, 0, "") is Err(_))
  assert_true(reclaim("", 30, 0, 1, 0, "") is Err(_))
}

///|
test "sixteen-event bound and full-day threshold produce exhaustive certificates" {
  let mut snapshot = "day 00:00 24:00"
  for i = 0; i < 16; i = i + 1 {
    snapshot = snapshot + "\nbusy e" + i.to_string() + " 09:00 10:00"
  }
  let report = reclaim(snapshot, 1440, 1440, 1440, 0, "").unwrap()
  assert_eq(report.diagnostics.total_subsets, 65536)
  assert_eq(report.diagnostics.evaluated_subsets, 1)
  assert_eq(report.diagnostics.budget_pruned_subsets, 65535)
  assert_eq(report.status, "infeasible")
}

///|
test "sixteen movable events exhaustive search stays practical" {
  let mut snapshot = "day 00:00 24:00"
  for i = 0; i < 16; i = i + 1 {
    snapshot = snapshot + "\nbusy e" + i.to_string() + " 09:00 10:00"
  }
  let report = reclaim(snapshot, 1440, 0, 1440, 160000, "").unwrap()
  assert_eq(report.diagnostics.total_subsets, 65536)
  assert_eq(report.diagnostics.evaluated_subsets, 65536)
  assert_eq(report.status, "feasible")
  assert_eq(report.solution.unwrap().removed_ids.length(), 16)
}

///|
test "reclaim frontier agrees with independent minute occupancy oracle" {
  let snapshot = "day 09:00 12:00\nbusy a 09:00 09:20\nbusy b 09:15 09:50\nfixed f 09:40 10:00\nbusy c 10:30 10:45"
  for recovery in [0, 15, 100] {
    for minimum in [1, 45, 90] {
      for budget = 0; budget <= 6; budget = budget + 1 {
        let best_by_cost = Array::make(7, -1)
        for mask = 0; mask < 8; mask = mask + 1 {
          let occupied = Array::make(180, false)
          let intervals = [(0, 20, 1), (15, 50, 2), (90, 105, 4), (40, 60, 0)]
          let mut cost = 0
          for (s, e, bit) in intervals {
            if bit != 0 && (mask & bit) != 0 {
              cost = cost +
                (if bit == 1 { 1 } else if bit == 2 { 2 } else { 3 })
            } else {
              for minute = s; minute < e; minute = minute + 1 {
                occupied[minute] = true
              }
            }
          }
          if cost > budget {
            continue
          }
          let mut minute = 0
          let mut focus = 0
          while minute < 180 {
            if occupied[minute] {
              minute = minute + 1
              continue
            }
            let s = minute
            while minute < 180 && !occupied[minute] {
              minute = minute + 1
            }
            let usable = minute - s - (if s > 0 { recovery } else { 0 })
            if usable >= minimum {
              focus = focus + usable
            }
          }
          if focus > best_by_cost[cost] {
            best_by_cost[cost] = focus
          }
        }
        let mut expected_best = -1
        let expected_frontier : Array[(Int, Int)] = []
        for cost = 0; cost <= budget; cost = cost + 1 {
          if best_by_cost[cost] > expected_best {
            expected_best = best_by_cost[cost]
            expected_frontier.push((cost, expected_best))
          }
        }
        let actual = reclaim(
          snapshot, minimum, recovery, 100, budget, "cost b 2\ncost c 3",
        ).unwrap()
        assert_eq(actual.best_focus_under_budget, expected_best)
        assert_eq(actual.frontier.length(), expected_frontier.length())
        for i = 0; i < expected_frontier.length(); i = i + 1 {
          assert_eq(
            (actual.frontier[i].cost, actual.frontier[i].focus_minutes),
            expected_frontier[i],
          )
        }
        let mut target_cost = -1
        for cost = 0; cost <= budget; cost = cost + 1 {
          if target_cost < 0 && best_by_cost[cost] >= 100 {
            target_cost = cost
          }
        }
        match actual.solution {
          None => assert_eq(target_cost, -1)
          Some(plan) => assert_eq(plan.cost, target_cost)
        }
      }
    }
  }
}
