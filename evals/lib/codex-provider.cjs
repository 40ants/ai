const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawn, spawnSync } = require('node:child_process');

function write(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content);
}
function files(root, prefix = '') {
  const result = {};
  for (const entry of fs.readdirSync(path.join(root, prefix), { withFileTypes: true })) {
    if (entry.name === '.agents' || entry.name === '.git') continue;
    const relative = path.posix.join(prefix, entry.name);
    const absolute = path.join(root, relative);
    if (entry.isSymbolicLink()) throw new Error(`Unexpected symlink: ${relative}`);
    if (entry.isDirectory()) Object.assign(result, files(root, relative));
    else {
      if (fs.statSync(absolute).size > 2 * 1024 * 1024) throw new Error(`Artifact too large: ${relative}`);
      result[relative] = fs.readFileSync(absolute, 'utf8');
    }
  }
  return result;
}
function run(command, args, options, timeoutMs) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, options);
    let stdout = '', stderr = '', timedOut = false;
    const timer = setTimeout(() => { timedOut = true; child.kill('SIGTERM'); }, timeoutMs);
    const killer = setTimeout(() => child.kill('SIGKILL'), timeoutMs + 5000);
    child.stdout.on('data', x => {
      stdout += x;
      if (options.tracePath) fs.appendFileSync(options.tracePath, x);
    });
    child.stderr.on('data', x => {
      stderr += x;
      if (options.stderrPath) fs.appendFileSync(options.stderrPath, x);
    });
    child.on('error', error => { clearTimeout(timer); clearTimeout(killer); reject(error); });
    child.on('close', code => {
      clearTimeout(timer); clearTimeout(killer);
      resolve({ code, stdout, stderr, timedOut });
    });
    child.stdin.end(options.input);
  });
}

function userSkillFiles() {
  const found = [], seen = new Set();
  function visit(dir) {
    if (!fs.existsSync(dir)) return;
    const real = fs.realpathSync(dir);
    if (seen.has(real)) return;
    seen.add(real);
    for (const name of fs.readdirSync(dir)) {
      const file = path.join(dir, name);
      if (fs.statSync(file).isDirectory()) visit(file);
      else if (name.toLowerCase() === 'skill.md') found.push(file);
    }
  }
  visit(path.join(os.homedir(), '.agents/skills'));
  visit('/etc/codex/skills');
  return found;
}

module.exports = class CodexProvider {
  constructor(options = {}) { this.config = options.config || {}; }
  id() { return `codex-cli:${this.config.variant || 'with-skill'}`; }
  async callApi(prompt, context) {
    const runDir = process.env.SKILL_EVAL_RUN_DIR;
    if (!runDir) return { error: 'Run through node evals/run.mjs run (missing SKILL_EVAL_RUN_DIR)' };
    if (!process.env.SKILL_EVAL_TOOL_PATH) return { error: 'Enter the pinned project nix-shell first' };
    const variant = this.config.variant || 'with-skill';
    const v = context.vars;
    const sampleId = `${v.id}-${variant}-${crypto.randomUUID().slice(0, 8)}`;
    const artifactDir = path.join(runDir, 'samples', sampleId);
    const scratch = fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()), 'cl-skill-eval-'));
    const workspace = path.join(scratch, 'workspace');
    const isolatedHome = path.join(scratch, 'codex-home');
    fs.mkdirSync(workspace, { recursive: true });
    fs.mkdirSync(isolatedHome, { recursive: true, mode: 0o700 });
    fs.mkdirSync(artifactDir, { recursive: true });
    let result;
    try {
      const initialized = spawnSync('git', ['init', '--quiet', workspace], { encoding: 'utf8' });
      if (initialized.status !== 0) throw new Error(`Cannot create fixture Git root: ${initialized.stderr}`);
      // Only authentication is reused. Personal config, skills, memory and MCP
      // settings are absent. Auth lives outside all persisted eval artifacts.
      const userCodexHome = process.env.CODEX_HOME || path.join(os.homedir(), '.codex');
      const authFile = path.join(userCodexHome, 'auth.json');
      if (fs.existsSync(authFile)) fs.symlinkSync(authFile, path.join(isolatedHome, 'auth.json'));
      for (const [relative, content] of Object.entries(v.fixtures || {})) {
        if (relative.startsWith('/') || relative.split('/').includes('..')) throw new Error('Invalid fixture path');
        write(path.join(workspace, relative), content);
      }
      if (variant === 'with-skill') {
        fs.cpSync(path.join(runDir, 'skill'), path.join(workspace, '.agents/skills/writing-common-lisp'), { recursive: true });
      } else {
        // An explicit request to use an absent skill would be an unfair control.
        prompt = prompt.replace(/Use \$writing-common-lisp(?: and follow this project's conventions)?\.\s*/g, '');
      }
      const args = [
        'exec', '--json', '--ignore-user-config', '--ignore-rules', '--ephemeral',
        '--skip-git-repo-check', '--sandbox', 'workspace-write',
        '--config', 'approval_policy="never"',
        '--config', 'web_search="disabled"',
        '--config', 'features.memories=false',
        '--config', 'allow_login_shell=false',
        '--config', `shell_environment_policy.set.PATH=${JSON.stringify(process.env.SKILL_EVAL_TOOL_PATH)}`,
        '--config', `shell_environment_policy.set.ZDOTDIR=${JSON.stringify(isolatedHome)}`,
        '--config', `shell_environment_policy.set.XDG_CACHE_HOME=${JSON.stringify(path.join(scratch, 'cache'))}`,
        '--model', process.env.SKILL_EVAL_MODEL,
        '--config', `model_reasoning_effort="${process.env.SKILL_EVAL_EFFORT}"`,
        '--cd', workspace, '-'
      ];
      const disabled = userSkillFiles().map(file => `{ path = ${JSON.stringify(file)}, enabled = false }`);
      if (disabled.length) args.splice(-1, 0, '--config', `skills.config=[${disabled.join(',')}]`);
      write(path.join(artifactDir, 'prompt.txt'), prompt);
      const started = Date.now();
      result = await run('codex', args, {
        cwd: workspace,
        env: { ...process.env, PATH: process.env.SKILL_EVAL_TOOL_PATH, CODEX_HOME: isolatedHome },
        stdio: ['pipe', 'pipe', 'pipe'], input: prompt,
        tracePath: path.join(artifactDir, 'trace.jsonl'),
        stderrPath: path.join(artifactDir, 'stderr.log')
      }, Number(process.env.SKILL_EVAL_TIMEOUT_MS || 240000));
      write(path.join(artifactDir, 'trace.jsonl'), result.stdout);
      write(path.join(artifactDir, 'stderr.log'), result.stderr);
      const events = result.stdout.split('\n').filter(Boolean).map(line => JSON.parse(line));
      const completed = events.filter(e => e.type === 'item.completed');
      const commands = completed.filter(e => e.item?.type === 'command_execution').map(e => e.item);
      const skillPath = '.agents/skills/writing-common-lisp/SKILL.md';
      // Evidence of a successful direct file read, not a first-class invocation
      // event. Broad reads and commands that merely mention a path don't count.
      const skillRead = commands.some(c => c.exit_code === 0 && c.command.includes(skillPath)
        && /\b(cat|sed|head|tail|bat)\b/.test(c.command));
      const usage = events.filter(e => e.type === 'turn.completed').reduce((total, e) => {
        for (const [k, n] of Object.entries(e.usage || {})) total[k] = (total[k] || 0) + n;
        return total;
      }, {});
      const envelope = {
        sampleId, variant, files: files(workspace), skillRead,
        commandCount: commands.length, durationMs: Date.now() - started, usage,
        final: completed.filter(e => e.item?.type === 'agent_message').map(e => e.item.text).join('\n'),
        trace: path.relative(runDir, path.join(artifactDir, 'trace.jsonl'))
      };
      for (const [relative, content] of Object.entries(envelope.files)) write(path.join(artifactDir, 'files', relative), content);
      write(path.join(artifactDir, 'sample.json'), JSON.stringify(envelope, null, 2));
      const failure = events.find(e => e.type === 'turn.failed' || e.type === 'error');
      if (result.code !== 0 || result.timedOut || failure) {
        return { error: `Codex failed (${result.code}${result.timedOut ? ', timeout' : ''}): ${JSON.stringify(failure || result.stderr.slice(-1500))}`, metadata: { sampleId } };
      }
      if (!events.some(e => e.type === 'turn.completed')) return { error: 'Codex did not complete a turn', metadata: { sampleId } };
      return {
        output: JSON.stringify(envelope),
        tokenUsage: { prompt: usage.input_tokens || 0, completion: usage.output_tokens || 0,
          total: (usage.input_tokens || 0) + (usage.output_tokens || 0), cached: usage.cached_input_tokens || 0 },
        metadata: { sampleId, skillRead, commandCount: commands.length }
      };
    } catch (error) {
      return { error: `${error.message}; artifacts: ${artifactDir}` };
    } finally {
      // Only this process's exact mkdtemp directory, never the project or home.
      fs.rmSync(scratch, { recursive: true, force: true });
    }
  }
};
