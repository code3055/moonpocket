///|
test "planner solves value tradeoffs rather than selecting longest or highest-value task first" {
  let (tasks, _) = parse_tasks(
    "task big 90 09:00 11:00 10 deep\ntask first 60 09:00 11:00 6 deep\ntask second 60 09:00 11:00 6 deep",
    540, 660,
  ).unwrap()
  let r = solve_tasks(tasks, [(540, 660)], [], 540, 0)
  assert_eq(r.total_value, 12)
  assert_eq(r.scheduled_count, 2)
}

///|
test "planner accounts for dependencies switching and fragmented capacity" {
  let (tasks, _) = parse_tasks(
    "task a 30 09:00 11:00 5 code\ntask b 30 09:00 11:00 10 mail\nafter b a", 540,
    660,
  ).unwrap()
  let r = solve_tasks(tasks, [(540, 600), (630, 660)], [], 540, 10)
  assert_eq(r.total_value, 15)
  assert_eq(r.assignments[0].task_id, "a")
  assert_eq(r.assignments[1].start, "10:30")
  let tight = solve_tasks(tasks, [(540, 600)], [], 540, 10)
  assert_eq(tight.total_value, 5)
}

///|
test "planner rejects dependency cycles and unknown parents" {
  for
    input in [
      "task a 30 09:00 11:00 5 c\nafter a missing", "task a 30 09:00 11:00 5 c\ntask b 30 09:00 11:00 5 c\nafter a b\nafter b a",
      "task a 0 09:00 11:00 5 c",
    ] {
    match parse_tasks(input, 540, 660) {
      Err(_) => ()
      Ok(_) => fail("invalid tasks accepted")
    }
  }
}

///|
test "planner explains infeasible tasks and accepts empty task lists" {
  let (tasks, _) = parse_tasks("task a 90 09:00 10:00 5 c", 540, 660).unwrap()
  let r = solve_tasks(tasks, [(540, 660)], [], 540, 0)
  assert_eq(r.total_value, 0)
  assert_eq(r.unscheduled[0].reason, "no_contiguous_window")
  let empty = solve_tasks([], [(540, 660)], [], 540, 0)
  assert_eq(empty.scheduled_count, 0)
}

///|
test "planner enforces declared resource windows" {
  let (tasks, resources) = parse_tasks(
    "resource gpu 09:00 10:00\ntask render 30 09:00 11:00 8 batch gpu\ntask note 30 09:00 11:00 3 writing",
    540, 660,
  ).unwrap()
  let plan = solve_tasks(tasks, [(540, 660)], resources, 540, 0)
  assert_eq(plan.total_value, 11)
  assert_eq(plan.assignments[0].task_id, "render")
  assert_eq(plan.assignments[1].task_id, "note")
}

///|
test "planner strategies change the objective without changing feasibility" {
  let day = "day 09:00 12:00"
  let tasks = "task short 30 09:00 12:00 1 c\ntask valuable 60 09:00 12:00 10 c"
  let value = plan_schedule_with_strategy(day, tasks, 0, 0, "value").unwrap()
  let count = plan_schedule_with_strategy(day, tasks, 0, 0, "count").unwrap()
  assert_eq(value.objective, "max_value_then_count_then_earliest_finish")
  assert_eq(count.objective, "max_count_then_value_then_earliest_finish")
  assert_true(value.total_value >= count.total_value)
  assert_true(count.scheduled_count >= value.scheduled_count)
  assert_true(plan_schedule_with_strategy(day, tasks, 0, 0, "other") is Err(_))
}
