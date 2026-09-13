// Run with: node tests/config-regressions.mjs (bash, git and jq required).
// Real git repositories and files, with only deployment/device commands mocked.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
const root = new URL('../', import.meta.url);
const source = name => fs.readFileSync(new URL(name, root), 'utf8');
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'nixos-regressions-'));
let passed = 0;
function run(command, args, options = {}) {
  const r = spawnSync(command, args, { encoding: 'utf8', ...options });
  assert.ifError(r.error);
  return r;
}
function test(name, body) {
  const dir = path.join(temp, String(passed));
  fs.mkdirSync(dir);
  body(dir);
  passed++;
  console.log(`ok ${passed} - ${name}`);
}
const shell = source('hm/shell.nix');
const update = shell.slice(shell.indexOf('      _update_flake_input()'), shell.indexOf('      # Claude Code / Codex の更新ショートカット'));
const updateMocks = `
cd() { builtin cd "$TEST_DIR"; }
nix() {
  echo "nix $*" >> "$TEST_DIR.calls"
  if [ "$1 $2" = "flake update" ]; then
    [ "$TEST_CASE" = update_failure ] && return 42
    [ "$TEST_CASE" = unchanged ] && return 0
    printf 'updated\\n' > flake.lock
    [ "$TEST_CASE" = partial_failure ] && return 42
  elif [ "$TEST_CASE" = check_failure ]; then return 42; fi
  return 0
}
sudo() {
  echo "sudo $*" >> "$TEST_DIR.calls"
  [ "$TEST_CASE:$2" = test_failure:test ] && return 42
  [ "$TEST_CASE:$2" = switch_failure:switch ] && return 42
  return 0
}
git() {
  if [ "$1" = commit ] && [ "$TEST_CASE" = commit_failure ]; then return 42; fi
  command git "$@"
}
`;
for (const scenario of ['staged', 'unstaged', 'staged_restored', 'other_staged', 'other_unstaged', 'untracked', 'update_failure', 'partial_failure', 'check_failure', 'test_failure', 'commit_failure', 'switch_failure', 'unchanged', 'success']) {
  test(`update: ${scenario}`, dir => {
    const git = (...args) => {
      const r = run('git', args, { cwd: dir });
      assert.equal(r.status, 0, r.stderr);
      return r.stdout.trim();
    };
    git('init', '-q');
    for (const [k, v] of [['user.name', 'Test'], ['user.email', 'test@example.invalid'], ['commit.gpgsign', 'false'], ['core.hooksPath', '/dev/null']]) git('config', k, v);
    fs.writeFileSync(path.join(dir, 'flake.lock'), 'original\n');
    fs.writeFileSync(path.join(dir, 'other'), 'original\n');
    git('add', 'flake.lock', 'other'); git('commit', '-qm', 'initial');
    if (scenario === 'other_staged' || scenario === 'other_unstaged') {
      fs.writeFileSync(path.join(dir, 'other'), 'unrelated\n');
      if (scenario === 'other_staged') git('add', 'other');
    }
    if (scenario === 'untracked') fs.writeFileSync(path.join(dir, 'new.nix'), '{}');
    if (['staged', 'unstaged', 'staged_restored'].includes(scenario)) {
      fs.writeFileSync(path.join(dir, 'flake.lock'), 'existing\n');
      if (scenario !== 'unstaged') git('add', 'flake.lock');
      if (scenario === 'staged_restored') fs.writeFileSync(path.join(dir, 'flake.lock'), 'original\n');
    }
    const r = run('bash', ['--noprofile', '--norc', '-c', updateMocks + update + '\n_update_flake_input test "test update"'], {
      env: { ...process.env, TEST_DIR: dir, TEST_CASE: scenario }
    });
    assert.equal(r.status, ['success', 'unchanged'].includes(scenario) ? 0 : 1, r.stdout + r.stderr);
    const calls = fs.existsSync(dir + '.calls') ? fs.readFileSync(dir + '.calls', 'utf8') : '';
    assert.equal(calls.includes('nixos-rebuild switch'), ['success', 'switch_failure'].includes(scenario));
    if (['staged', 'unstaged', 'staged_restored', 'other_staged', 'other_unstaged', 'untracked'].includes(scenario)) assert.equal(calls, '');
    const expected = scenario === 'staged_restored' ? 'original\n' : ['staged', 'unstaged', 'staged_restored'].includes(scenario) ? 'existing\n' : ['success', 'switch_failure', 'commit_failure'].includes(scenario) ? 'updated\n' : 'original\n';
    assert.equal(fs.readFileSync(path.join(dir, 'flake.lock'), 'utf8'), expected);
    assert.equal(git('diff', '--cached', '--name-only').split('\n').includes('other'), scenario === 'other_staged');
    assert.equal(git('rev-list', '--count', 'HEAD'), ['success', 'switch_failure'].includes(scenario) ? '2' : '1');
  });
}
const jsonScript = new URL('hm/scripts/update-claude-json.sh', root).pathname;
const desired = { type: 'command', command: 'example' };
const updateJson = file => run('bash', ['-euo', 'pipefail', jsonScript, file, '["statusLine"]', JSON.stringify(desired)]);
for (const original of ['{bad', '', '[]', 'null', '{}\n{}']) {
  test(`JSON: preserve invalid ${JSON.stringify(original)}`, dir => {
    const file = path.join(dir, 'settings.json'); fs.writeFileSync(file, original);
    const r = updateJson(file); assert.equal(r.status, 0, r.stderr);
    assert.equal(fs.readFileSync(file, 'utf8'), original);
    const backups = fs.readdirSync(dir).filter(x => x.includes('.invalid.'));
    assert.equal(backups.length, 1);
    const backup = path.join(dir, backups[0]);
    assert.equal(fs.readFileSync(backup, 'utf8'), original);
    assert.equal(fs.statSync(backup).mode & 0o777, 0o600);
    assert.equal(fs.readdirSync(dir).length, 2);
  });
}
test('JSON: create missing file privately', dir => {
  const file = path.join(dir, 'nested', 'settings.json');
  assert.equal(updateJson(file).status, 0);
  assert.deepEqual(JSON.parse(fs.readFileSync(file)), { statusLine: desired });
  assert.equal(fs.statSync(file).mode & 0o777, 0o600);
});
test('JSON: preserve unrelated settings and skip identical content', dir => {
  const file = path.join(dir, 'settings.json');
  const original = { permissions: { deny: ['Bash(rm *)'] }, enabledPlugins: { example: true } };
  fs.writeFileSync(file, JSON.stringify(original));
  assert.equal(updateJson(file).status, 0);
  assert.deepEqual(JSON.parse(fs.readFileSync(file)), { ...original, statusLine: desired });
  const inode = fs.statSync(file).ino;
  assert.equal(updateJson(file).status, 0);
  assert.equal(fs.statSync(file).ino, inode);
  assert.deepEqual(fs.readdirSync(dir), ['settings.json']);
});
const mouse = source('hm/mouse.nix').split("    text = ''\n")[1].split("\n    '';\n")[0].replaceAll("''${", '${');
for (const scenario of ['command_failure', 'stop_failure', 'start_failure', 'INT', 'TERM', 'success']) {
  test(`Solaar: ${scenario}`, dir => {
    fs.mkdirSync(path.join(dir, 'solaar'));
    fs.writeFileSync(path.join(dir, 'solaar/config.yaml'), 'divert-keys: {83: 1, 86: 1, 196: 1, 195: 2, 416: 2}\n');
    const mocks = `
systemctl() {
  echo "$*" >> "$TEST_DIR.calls"
  [ "$TEST_CASE:$2" = stop_failure:stop ] && return 42
  [ "$TEST_CASE:$2" = start_failure:start ] && return 42
  return 0
}
solaar() {
  [ "$TEST_CASE" = command_failure ] && return 42
  if [ "$TEST_CASE" = INT ] || [ "$TEST_CASE" = TERM ]; then kill -s "$TEST_CASE" "$$"; fi
  printf 'dpi = 1500\\nscroll-ratchet = Ratcheted\\nsmart-shift = 10\\nscroll-ratchet-torque = 50\\nhires-smooth-resolution = False\\n'
}
`;
    const r = run('bash', ['-euo', 'pipefail', '-c', mocks + mouse], {
      env: { ...process.env, TEST_DIR: dir, TEST_CASE: scenario, XDG_CONFIG_HOME: dir }
    });
    const expected = { success: 0, INT: 130, TERM: 143, start_failure: 1 }[scenario] ?? 42;
    assert.equal(r.status, expected, r.stdout + r.stderr);
    const calls = fs.readFileSync(dir + '.calls', 'utf8');
    assert.ok(calls.includes('--user stop solaar.service'));
    assert.ok(calls.includes('--user start solaar.service'));
    if (scenario === 'success') assert.equal(calls.split('start solaar.service').length - 1, 1);
  });
}
fs.rmSync(temp, { recursive: true });
console.log(`${passed} regression cases passed`);
