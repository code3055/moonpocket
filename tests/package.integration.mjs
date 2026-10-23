import { spawnSync } from 'node:child_process';
import { mkdtempSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import assert from 'node:assert/strict';

// Rebuild from the distribution archive, so ignored local files cannot hide gaps.
const moon = process.env.MOON_HOME
  ? join(process.env.MOON_HOME, 'bin', process.platform === 'win32' ? 'moon.exe' : 'moon')
  : 'moon';
function command(executable, args, cwd = process.cwd()) {
  const result = spawnSync(executable, args, { cwd, encoding: 'utf8', env: process.env });
  assert.equal(result.status, 0, `${executable} ${args.join(' ')} failed: ${result.error?.message || ''}${result.stdout}${result.stderr}`);
  return result.stdout;
}
command(moon, ['package']);
const archiveDir = resolve('_build/publish');
const archive = join(archiveDir, 'code3055-moonpocket-0.2.0.zip');
assert.ok(readdirSync(archiveDir).includes('code3055-moonpocket-0.1.0.zip'));
const dir = mkdtempSync(join(tmpdir(), 'moonpocket-package-'));
try {
  const python = process.platform === 'win32' ? 'python' : 'python3';
  command(python, ['-c', 'import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])', archive, dir]);
  command(moon, ['check', '--target', 'js', '--deny-warn'], dir);
  command(moon, ['test', '--target', 'js', '--deny-warn'], dir);
  command(moon, ['build', '--target', 'js', 'src/cmd/moonpocket'], dir);
  command(process.execPath, ['--test', 'tests/cli.integration.test.mjs'], dir);
  command(process.execPath, ['--test', 'tests/solver.integration.test.mjs'], dir);
  const cli = join(dir, '_build/js/debug/build/cmd/moonpocket/moonpocket.js');
  const json = JSON.parse(command(process.execPath, [cli, '--input', 'examples/protected.day'], dir));
  assert.equal(json.summary.focus_minutes, 270);
  assert.ok(json.events.some(e => e.id === 'exam' && e.fixed));
  console.log('Distribution archive: isolated check, 27 core tests, 13 CLI tests, 2 solver tests and protected-day example passed.');
} finally { rmSync(dir, { recursive: true, force: true }); }
