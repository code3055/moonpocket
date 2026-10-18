import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
const cli = resolve('_build/js/debug/build/cmd/moonpocket/moonpocket.js');
const run = (...args) => spawnSync(process.execPath, [cli, ...args], { encoding: 'utf8' });
test('quiet day has 470 focus minutes after recovery and emits SVG', () => {
  const dir = mkdtempSync(join(tmpdir(), 'moonpocket-'));
  try {
    const report = join(dir, 'report.json');
    const svg = join(dir, 'timeline.svg');
    const result = run('--input', 'examples/quiet.day', '--report', report, '--svg', svg);
    assert.equal(result.status, 0, result.stderr);
    const json = JSON.parse(readFileSync(report, 'utf8'));
    assert.equal(json.summary.focus_minutes, 470);
    assert.equal(json.summary.busy_minutes, 60);
    assert.equal(json.summary.free_minutes, 480);
    assert.equal(json.summary.largest_focus, 290);
    assert.match(readFileSync(svg, 'utf8'), /<svg/);
    assert.deepEqual(JSON.parse(result.stdout), json);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
test('focus gate returns 1 and still prints a usable report', () => {
  const result = run('--input', 'examples/quiet.day', '--require-focus', '471');
  assert.equal(result.status, 1, result.stderr);
  assert.equal(JSON.parse(result.stdout).summary.focus_minutes, 470);
});
test('invalid arguments and missing input return 2', () => {
  for (const args of [['--unknown', 'x'], ['--input'], ['--recovery', '-1'], ['--min-focus', '0'], ['--input', 'missing.day']]) {
    assert.equal(run(...args).status, 2, args.join(' '));
  }
});
test('invalid snapshot reports a line and does not write output', () => {
  const dir = mkdtempSync(join(tmpdir(), 'moonpocket-'));
  try {
    const input = join(dir, 'bad.day');
    writeFileSync(input, 'day 09:00 18:00\nbusy bad 08:00 10:00\n');
    const result = run('--input', input);
    assert.equal(result.status, 2);
    assert.match(result.stderr, /line|Line/);
    assert.equal(result.stdout, '');
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
test('deterministic report and useful removal suggestions', () => {
  const one = run('--input', 'examples/fragmented.day');
  const two = run('--input', 'examples/fragmented.day');
  assert.equal(one.status, 0, one.stderr);
  assert.equal(one.stdout, two.stdout);
  const report = JSON.parse(one.stdout);
  assert.ok(report.suggestions.length > 0);
  assert.ok(report.suggestions.every(s => s.gain_minutes > 0));
});
test('write failures and same input/output path return 2', () => {
  assert.equal(run('--report', 'missing-directory/out.json').status, 2);
  assert.equal(run('--input', 'examples/quiet.day', '--report', 'examples/quiet.day').status, 2);
  assert.equal(run('--input', 'examples/quiet.day', '--report', './examples/quiet.day').status, 2);
});
test('help is available without a snapshot', () => {
  const result = run('--help');
  assert.equal(result.status, 0);
  assert.match(result.stdout, /--require-focus/);
});
test('interval accounting agrees with an independent minute-by-minute oracle', () => {
  const dir = mkdtempSync(join(tmpdir(), 'moonpocket-oracle-'));
  const time = n => `${String(Math.floor(n / 60)).padStart(2, '0')}:${String(n % 60).padStart(2, '0')}`;
  let seed = 1234567;
  const random = max => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed % max; };
  const oracle = (events, threshold, recovery) => {
    const busy = Array(180).fill(false);
    for (const [start, end] of events) for (let i = start; i < end; i++) busy[i] = true;
    let focus = 0, largest = 0, count = 0;
    for (let i = 0; i < busy.length;) {
      if (busy[i]) { i++; continue; }
      const start = i;
      while (i < busy.length && !busy[i]) i++;
      const usable = Math.max(0, i - start - (start > 0 ? recovery : 0));
      if (usable >= threshold) { focus += usable; largest = Math.max(largest, usable); count++; }
    }
    const busyMinutes = busy.filter(Boolean).length;
    return { busy_minutes: busyMinutes, free_minutes: 180 - busyMinutes, focus_minutes: focus, fragment_minutes: 180 - busyMinutes - focus, largest_focus: largest, focus_count: count };
  };
  try {
    for (let scenario = 0; scenario < 24; scenario++) {
      const events = Array.from({ length: random(9) }, () => { const start = random(179); return [start, Math.min(180, start + 1 + random(60))]; });
      const threshold = 1 + random(60), recovery = random(31);
      const snapshot = ['day 09:00 12:00', ...events.map(([s, e], i) => `busy e${i} ${time(540 + s)} ${time(540 + e)}`)].join('\n');
      const input = join(dir, 'random.day');
      writeFileSync(input, snapshot);
      const result = run('--input', input, '--min-focus', String(threshold), '--recovery', String(recovery));
      assert.equal(result.status, 0, result.stderr);
      const report = JSON.parse(result.stdout), expected = oracle(events, threshold, recovery);
      assert.deepEqual(report.summary, expected, `scenario ${scenario}`);
      const suggestions = events.flatMap((_, i) => {
        const after = oracle(events.filter((_, j) => i !== j), threshold, recovery);
        const gain = after.focus_minutes - expected.focus_minutes;
        return gain > 0 ? [{ event_id: `e${i}`, gain_minutes: gain, largest_focus: after.largest_focus }] : [];
      }).sort((a, b) => b.gain_minutes - a.gain_minutes || (a.event_id < b.event_id ? -1 : a.event_id > b.event_id ? 1 : 0));
      assert.deepEqual(report.suggestions, suggestions, `removal scenario ${scenario}`);
    }
  } finally { rmSync(dir, { recursive: true, force: true }); }
});


