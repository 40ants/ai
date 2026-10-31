#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import { spawn, spawnSync } from 'node:child_process';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const runsRoot = path.join(root, '.evals/runs');
const skillRelative = 'plugins/common-lisp-skills/skills/writing-common-lisp';
const suiteRelative = 'evals/writing-common-lisp';
const argv = process.argv.slice(2);
const command = argv.shift() || 'help';
const flags = {};
const positional = [];
while (argv.length) {
  const arg = argv.shift();
  if (arg.startsWith('--')) {
    const name = arg.slice(2);
    flags[name] = ['ablation', 'allow-mismatch'].includes(name) ? true : argv.shift();
    if (flags[name] === undefined) throw new Error(`Missing value for ${arg}`);
  } else positional.push(arg);
}
function write(file, object) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, typeof object === 'string' ? object : JSON.stringify(object, null, 2) + '\n');
}
function exec(program, args, options = {}) {
  const result = spawnSync(program, args, { cwd: root, encoding: 'utf8', ...options });
  if (result.error || result.status !== 0) throw new Error(`${program} ${args.join(' ')}: ${result.error?.message || result.stderr}`);
  return result.stdout.trim();
}
function digest(dir) {
  const hash = crypto.createHash('sha256');
  function visit(relative) {
    for (const name of fs.readdirSync(path.join(dir, relative)).sort()) {
      const file = path.posix.join(relative, name);
      const stat = fs.lstatSync(path.join(dir, file));
      if (stat.isSymbolicLink()) throw new Error(`Snapshot must not contain symlinks: ${file}`);
      if (stat.isDirectory()) visit(file);
      else hash.update(file + '\0').update(fs.readFileSync(path.join(dir, file))).update('\0');
    }
  }
  visit('');
  return hash.digest('hex');
}
const median = numbers => {
  if (!numbers.length) return null;
  const sorted = [...numbers].sort((a, b) => a - b), i = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[i] : (sorted[i - 1] + sorted[i]) / 2;
};
function histories() {
  if (!fs.existsSync(runsRoot)) return [];
  return fs.readdirSync(runsRoot).sort().filter(id => fs.existsSync(path.join(runsRoot, id, 'summary.json')))
    .map(id => JSON.parse(fs.readFileSync(path.join(runsRoot, id, 'summary.json'))));
}
function findRun(id) {
  const all = histories();
  if (id === 'latest') return all.at(-1);
  if (id === 'previous') return all.at(-2);
  const exact = all.find(r => r.id === id);
  if (exact) return exact;
  const labelled = all.filter(r => r.label === id);
  if (labelled.length > 1) throw new Error(`Ambiguous label ${id}; use an exact run ID from history`);
  return labelled[0];
}
function summarize(runDir, manifest, processStatus, processSignal = null) {
  const filename = path.join(runDir, 'results.json');
  const exported = fs.existsSync(filename) ? JSON.parse(fs.readFileSync(filename)) : null;
  const body = exported?.results;
  const raw = Array.isArray(body) ? body : body?.results || [];
  const rows = raw.map(r => {
    let sample = r.response?.metadata?.skillEval;
    // Old exports used an envelope as output; retain historical compatibility.
    if (!sample) try { sample = typeof r.response?.output === 'string' ? JSON.parse(r.response.output) : r.response?.output; } catch {}
    return {
      case: r.testCase?.vars?.id || r.vars?.id,
      variant: sample?.variant || r.provider?.label || r.provider?.id,
      pass: r.success === true, score: r.score,
      error: r.failureReason === 2 || r.response?.error ? (r.error || r.response?.error || 'Provider/grader error') : null,
      reason: r.gradingResult?.reason || null,
      tokens: sample?.usage ? (sample.usage.input_tokens || 0) + (sample.usage.output_tokens || 0) : r.response?.tokenUsage?.total ?? null,
      cachedInputTokens: sample?.usage.cached_input_tokens || 0,
      durationMs: sample?.durationMs ?? r.latencyMs, commands: sample?.commandCount,
      skillRead: sample?.skillRead, trace: sample?.trace
    };
  });
  const expected = manifest.cases.length * manifest.repeat * manifest.variants.length;
  const variants = {};
  for (const variant of manifest.variants) {
    const group = rows.filter(r => r.variant === variant || r.variant === `codex-cli:${variant}`);
    variants[variant] = {
      total: group.length, passed: group.filter(r => r.pass).length,
      failed: group.filter(r => !r.pass && !r.error).length,
      errors: group.filter(r => !!r.error).length,
      medianTokens: median(group.map(r => r.tokens).filter(Number.isFinite)),
      medianDurationMs: median(group.map(r => r.durationMs).filter(Number.isFinite)),
      medianCommands: median(group.map(r => r.commands).filter(Number.isFinite))
    };
  }
  const summary = {
    id: manifest.id, label: manifest.label, started: manifest.started,
    skillHash: manifest.skillHash, suiteHash: manifest.suiteHash,
    model: manifest.model, effort: manifest.effort, group: manifest.group,
    cases: manifest.cases, repeat: manifest.repeat, tools: manifest.tools,
    processStatus, processSignal, expected, observed: rows.length,
    coverageComplete: rows.length === expected,
    variants, rows, costUsd: null
  };
  write(path.join(runDir, 'summary.json'), summary);
  return summary;
}
function printSummary(summary) {
  console.log(`\n${summary.id} (${summary.label}) skill=${summary.skillHash.slice(0, 12)}`);
  console.table(summary.variants);
  if (!summary.coverageComplete) console.error(`INCOMPLETE COVERAGE: ${summary.observed}/${summary.expected}`);
  for (const row of summary.rows.filter(r => !r.pass)) console.log(`${row.case} [${row.variant}]: ${row.error || row.reason || 'failed'}`);
  console.log(`Artifacts: ${path.join(runsRoot, summary.id)}`);
}
if (command === 'run') {
  const allowed = ['ablation', 'label', 'model', 'effort', 'repeat', 'group', 'filter', 'ref', 'skill-dir', 'timeout'];
  for (const key of Object.keys(flags)) if (!allowed.includes(key)) throw new Error(`Unknown option --${key}`);
  const repeat = Number(flags.repeat || 1);
  if (!Number.isInteger(repeat) || repeat < 1 || repeat > 20) throw new Error('--repeat must be 1..20');
  const model = flags.model || 'gpt-6-sol';
  const effort = flags.effort || 'medium';
  if (!['low', 'medium', 'high', 'xhigh', 'max', 'ultra'].includes(effort)) throw new Error('Invalid reasoning effort');
  const group = flags.group || 'development';
  if (!['development', 'holdout', 'all'].includes(group)) throw new Error('--group: development, holdout or all');
  if (flags.ref && flags['skill-dir']) throw new Error('Use either --ref or --skill-dir');
  const cases = JSON.parse(fs.readFileSync(path.join(root, suiteRelative, 'cases.json')))
    .filter(c => (group === 'all' || c.vars.group === group) && (!flags.filter || new RegExp(flags.filter).test(c.description)));
  if (!cases.length) throw new Error('No matching cases; refusing an empty eval');
  const tools = Object.fromEntries(['promptfoo', 'codex', 'apm', 'sbcl', 'node'].map(tool => [tool, exec(tool, ['--version'])]));
  if (tools.promptfoo !== '0.125.1' || !tools.codex.includes('0.156.1') || !tools.apm.includes('0.31.0') || !process.env.SKILL_EVAL_TOOLCHAIN_DIR) {
    throw new Error('Unexpected tool versions. Enter the project nix-shell first.');
  }
  const require = createRequire(import.meta.url);
  tools.codexSdk = require(path.join(process.env.SKILL_EVAL_TOOLCHAIN_DIR, '@openai/codex-sdk/package.json')).version;
  if (tools.codexSdk !== '0.156.1') throw new Error('Unexpected Codex SDK version');
  const id = `${new Date().toISOString().replace(/[:.]/g, '-')}-${crypto.randomUUID().slice(0, 6)}`;
  const runDir = path.join(runsRoot, id);
  fs.mkdirSync(runDir, { recursive: true });
  const skillSnapshot = path.join(runDir, 'skill');
  if (flags.ref) {
    const revision = exec('git', ['rev-parse', '--verify', `${flags.ref}^{commit}`]);
    const archive = spawnSync('git', ['archive', revision, skillRelative], { cwd: root, maxBuffer: 16 * 1024 * 1024 });
    if (archive.status !== 0) throw new Error(archive.stderr.toString());
    const unpack = path.join(runDir, 'git-snapshot');
    fs.mkdirSync(unpack);
    exec('tar', ['-x', '-C', unpack], { input: archive.stdout });
    fs.cpSync(path.join(unpack, skillRelative), skillSnapshot, { recursive: true });
    fs.rmSync(unpack, { recursive: true });
  } else fs.cpSync(path.resolve(root, flags['skill-dir'] || skillRelative), skillSnapshot, { recursive: true });
  fs.cpSync(path.join(root, 'evals'), path.join(runDir, 'harness/evals'), { recursive: true });
  fs.copyFileSync(path.join(root, 'shell.nix'), path.join(runDir, 'harness/shell.nix'));
  fs.cpSync(path.join(root, 'nix'), path.join(runDir, 'harness/nix'), { recursive: true });
  const suiteHash = digest(path.join(runDir, 'harness'));
  const suiteDir = path.join(runDir, 'harness', suiteRelative);
  const variants = flags.ablation ? ['with-skill', 'without-skill'] : ['with-skill'];
  // Templates are immutable inputs; Promptfoo copies them for every call/repeat
  // and removes each working copy only after assertions have archived its files.
  for (const test of cases) {
    test.vars.taskWithoutSkill = test.vars.task.replace(/Use \$writing-common-lisp(?: and follow this project's conventions)?\.\s*/g, '');
    for (const variant of variants) {
      const workspace = path.join(runDir, 'fixtures', test.vars.id, variant);
      fs.mkdirSync(workspace, { recursive: true });
      exec('git', ['init', '--quiet', workspace]);
      for (const [relative, content] of Object.entries(test.vars.fixtures || {})) {
        if (path.isAbsolute(relative) || relative.split('/').includes('..')) throw new Error('Invalid fixture path');
        write(path.join(workspace, relative), content);
      }
      if (variant === 'with-skill') fs.cpSync(skillSnapshot, path.join(workspace, '.agents/skills/writing-common-lisp'), { recursive: true });
      test.vars[variant === 'with-skill' ? 'workspaceWithSkill' : 'workspaceWithoutSkill'] = workspace;
    }
  }
  write(path.join(suiteDir, 'selected-cases.json'), cases);
  const yaml = require(path.join(process.env.SKILL_EVAL_TOOLCHAIN_DIR, 'js-yaml'));
  const config = yaml.load(fs.readFileSync(path.join(suiteDir, 'promptfooconfig.yaml'), 'utf8'));
  config.tests = 'file://selected-cases.json';
  const disabledSkills = [];
  const seen = new Set();
  function disableSkills(dir) {
    if (!fs.existsSync(dir)) return;
    const real = fs.realpathSync(dir);
    if (seen.has(real)) return;
    seen.add(real);
    for (const name of fs.readdirSync(dir)) {
      const file = path.join(dir, name);
      if (fs.statSync(file).isDirectory()) disableSkills(file);
      else if (name.toLowerCase() === 'skill.md') disabledSkills.push({ path: file, enabled: false });
    }
  }
  disableSkills(path.join(os.homedir(), '.agents/skills'));
  disableSkills('/etc/codex/skills');
  const scratch = fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()), 'cl-eval-auth-'));
  fs.chmodSync(scratch, 0o700);
  // Only reuse login state. Never persist credentials in a run snapshot.
  const auth = path.join(process.env.CODEX_HOME || path.join(os.homedir(), '.codex'), 'auth.json');
  if (fs.existsSync(auth)) fs.symlinkSync(auth, path.join(scratch, 'auth.json'));
  const provider = config.providers[0];
  Object.assign(provider.config, {
    model, model_reasoning_effort: effort,
    cli_env: { PATH: process.env.SKILL_EVAL_TOOL_PATH, CODEX_HOME: scratch, ZDOTDIR: scratch, XDG_CACHE_HOME: path.join(scratch, 'cache') },
    cli_config: {
      'features.memories': false, allow_login_shell: false, 'skills.config': disabledSkills,
      'shell_environment_policy.set.PATH': process.env.SKILL_EVAL_TOOL_PATH,
      'shell_environment_policy.set.ZDOTDIR': scratch,
      'shell_environment_policy.set.XDG_CACHE_HOME': path.join(scratch, 'cache')
    }
  });
  if (flags.ablation) {
    config.prompts.push({ id: 'without-skill', label: 'without-skill-task', raw: '{{taskWithoutSkill}}' });
    config.providers.push({ ...provider, label: 'without-skill', prompts: ['without-skill'], config: { ...provider.config, working_dir: '{{workspaceWithoutSkill}}' } });
  }
  const configFile = path.join(suiteDir, 'effective.json');
  write(configFile, config);
  const manifest = {
    id, label: flags.label || 'unlabelled', started: new Date().toISOString(),
    skillSource: flags.ref || flags['skill-dir'] || 'working-tree', skillHash: digest(skillSnapshot), suiteHash,
    gitCommit: exec('git', ['rev-parse', 'HEAD']), gitStatus: exec('git', ['status', '--porcelain']),
    model, effort, repeat, group, cases: cases.map(c => c.vars.id), variants, tools,
    platform: `${os.platform()}-${os.arch()}`, timeoutMs: Number(flags.timeout || 240000),
    toolPath: process.env.SKILL_EVAL_TOOL_PATH,
    note: 'Model aliases can change server-side. Model names and client versions do not pin model weights.'
  };
  write(path.join(runDir, 'manifest.json'), manifest);
  const env = {
    ...process.env, PROMPTFOO_CONFIG_DIR: path.join(root, '.evals/promptfoo'),
    PROMPTFOO_DISABLE_TELEMETRY: '1', PROMPTFOO_DISABLE_UPDATE: '1',
    SKILL_EVAL_RUN_DIR: runDir, SKILL_EVAL_MODEL: model, SKILL_EVAL_EFFORT: effort,
    SKILL_EVAL_TIMEOUT_MS: String(manifest.timeoutMs)
  };
  env.PROMPTFOO_EVAL_TIMEOUT_MS = String(manifest.timeoutMs);
  console.log(`Running ${cases.length} cases × ${repeat} repeats × ${variants.length} variants; model=${model}/${effort}`);
  console.log(`Run: ${id}`);
  const args = ['eval', '-c', configFile, '-o', path.join(runDir, 'results.json'), '--no-cache', '--no-share', '--no-table', '--repeat', String(repeat), '--max-concurrency', '1'];
  let child;
  try { child = await new Promise(resolve => {
    const processChild = spawn('promptfoo', args, { cwd: root, env, stdio: ['ignore', 'pipe', 'pipe'] });
    processChild.stdout.on('data', chunk => {
      process.stdout.write(chunk);
      fs.appendFileSync(path.join(runDir, 'promptfoo.stdout.log'), chunk);
    });
    processChild.stderr.on('data', chunk => {
      process.stderr.write(chunk);
      fs.appendFileSync(path.join(runDir, 'promptfoo.stderr.log'), chunk);
    });
    processChild.on('error', error => {
      write(path.join(runDir, 'promptfoo.spawn-error.log'), error.message);
      resolve({ status: 1, signal: null });
    });
    processChild.on('close', (status, signal) => resolve({ status, signal }));
  }); } finally { fs.rmSync(scratch, { recursive: true, force: true }); }
  const summary = summarize(runDir, manifest, child.status, child.signal);
  printSummary(summary);
  process.exitCode = summary.coverageComplete && summary.rows.every(r => r.pass) && child.status === 0 ? 0 : 1;
} else if (command === 'history') {
  console.table(histories().map(s => ({
    id: s.id, label: s.label, skill: s.skillHash.slice(0, 10), model: s.model,
    cases: `${s.observed}/${s.expected}`, passed: s.rows.filter(r => r.pass).length,
    errors: s.rows.filter(r => !!r.error).length,
    tokens: s.variants['with-skill']?.medianTokens
  })));
} else if (command === 'compare') {
  const a = findRun(positional[0] || 'previous'), b = findRun(positional[1] || 'latest');
  if (!a || !b) throw new Error('Need two existing run IDs or unique labels; list them with history');
  const mismatches = ['suiteHash', 'model', 'effort', 'group', 'cases', 'repeat', 'tools'].filter(k => JSON.stringify(a[k]) !== JSON.stringify(b[k]));
  if (mismatches.length && !flags['allow-mismatch']) throw new Error(`Not directly comparable: ${mismatches.join(', ')}. Inspect settings or explicitly use --allow-mismatch.`);
  console.log(`${a.id} → ${b.id}`);
  if (mismatches.length) console.log(`CAUTION: differing ${mismatches.join(', ')}`);
  console.table([a, b].map(s => ({ run: s.label, skill: s.skillHash.slice(0, 12), ...s.variants['with-skill'] })));
  const keys = [...new Set([...a.rows, ...b.rows].map(r => `${r.case} / ${r.variant}`))];
  const rowStat = (s, key) => {
    const rows = s.rows.filter(r => `${r.case} / ${r.variant}` === key);
    return rows.length ? `${rows.filter(r => r.pass).length}/${rows.length}` : '—';
  };
  console.table(keys.map(key => ({ case: key, before: rowStat(a, key), after: rowStat(b, key) })));
} else if (command === 'view') {
  const child = spawnSync('promptfoo', ['view', '--port', '15500', '--no'], {
    cwd: root, stdio: 'inherit', env: { ...process.env, PROMPTFOO_CONFIG_DIR: path.join(root, '.evals/promptfoo') }
  });
  process.exitCode = child.status || 0;
} else {
  console.log(`From the project nix-shell:
  node evals/run.mjs run --label baseline
  node evals/run.mjs run --label smoke --filter package-path
  node evals/run.mjs run --label repeated --repeat 3
  node evals/run.mjs run --label full --group all
  node evals/run.mjs run --label ablation --ablation
  node evals/run.mjs run --label old --ref HEAD
  node evals/run.mjs history
  node evals/run.mjs compare RUN_A RUN_B
  node evals/run.mjs view`);
}
