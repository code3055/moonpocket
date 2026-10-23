///|
test "parallel scheduler allows independent tasks up to resource capacity" {
  let day = "day 09:00 10:00"
  let tasks = "task a 60 09:00 10:00 5 c gpu\ntask b 60 09:00 10:00 4 c gpu"
  let plan = parallel_schedule(day, tasks, "capacity gpu 2", 0).unwrap()
  assert_eq(plan.scheduled_count, 2)
  assert_eq(plan.assignments[0].start, "09:00")
  assert_eq(plan.assignments[1].start, "09:00")
  let limited = parallel_schedule(day, tasks, "capacity gpu 1", 0).unwrap()
  assert_eq(limited.scheduled_count, 1)
}
