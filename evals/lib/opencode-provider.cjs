// OpenCode transport only. Lifecycle, response interpretation, and artifact
// collection belong to the Lisp provider command.
const path = require('node:path');
const { spawn } = require('node:child_process');

const MAX_STDOUT = 8 * 1024 * 1024;
const MAX_STDERR = 8192;
const ABORT_GRACE_MS = 1000;

function validTimeout(value) {
  return Number.isSafeInteger(value) && value >= 1 && value <= 24 * 60 * 60 * 1000;
}

function terminateGroup(child) {
  if (!child.pid) return;
  try { process.kill(-child.pid, 'SIGTERM'); } catch { return; }
  const killTimer = setTimeout(() => {
    try { process.kill(-child.pid, 'SIGKILL'); } catch { /* Already exited. */ }
  }, ABORT_GRACE_MS);
  killTimer.unref();
}

function runLisp(harness, request, timeout, overallTimeout, abortSignal) {
  return new Promise((resolve, reject) => {
    if (abortSignal?.aborted) {
      reject(new Error('OpenCode provider request aborted'));
      return;
    }
    const script = path.join(harness, 'roswell/ai-evals.ros');
    const child = spawn('ros', ['-Q', '--', script, 'provider'], {
      cwd: harness,
      env: process.env,
      shell: false,
      detached: true,
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    let stdout = '';
    let stderr = '';
    let settled = false;
    let timer;
    const finish = (error, value) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      abortSignal?.removeEventListener('abort', onAbort);
      if (error) terminateGroup(child);
      error ? reject(error) : resolve(value);
    };
    const onAbort = () => finish(new Error('OpenCode provider request aborted'));
    timer = setTimeout(
      () => finish(new Error(
        `OpenCode provider transport deadline exceeded after ${overallTimeout}ms (execution timeout ${timeout}ms)`,
      )),
      overallTimeout,
    );
    abortSignal?.addEventListener('abort', onAbort, { once: true });
    child.on('error', error => finish(new Error(`Could not start Lisp OpenCode provider: ${error.message}`)));
    child.stdin.on('error', error => finish(new Error(`Could not send Lisp OpenCode request: ${error.message}`)));
    child.stdout.setEncoding('utf8');
    child.stderr.setEncoding('utf8');
    child.stdout.on('data', chunk => {
      stdout += chunk;
      if (Buffer.byteLength(stdout, 'utf8') > MAX_STDOUT) finish(new Error('Lisp provider response exceeds 8 MiB'));
    });
    child.stderr.on('data', chunk => { stderr = (stderr + chunk).slice(-MAX_STDERR); });
    child.on('close', code => {
      if (settled) return;
      if (code !== 0) return finish(new Error(`Lisp OpenCode provider exited ${code}: ${stderr}`));
      let response;
      try { response = JSON.parse(stdout); }
      catch { return finish(new Error(`Invalid Lisp provider JSON: ${stdout.slice(0, 200)}`)); }
      if (!response || typeof response !== 'object' || Array.isArray(response)) {
        return finish(new Error('Invalid Lisp ProviderResponse: expected a JSON object'));
      }
      if (!Object.hasOwn(response, 'output') && !Object.hasOwn(response, 'error')) {
        return finish(new Error('Invalid Lisp ProviderResponse: expected output or error'));
      }
      if (Object.hasOwn(response, 'error') && typeof response.error !== 'string') {
        return finish(new Error('Invalid Lisp ProviderResponse: error must be a string'));
      }
      for (const key of ['metadata', 'tokenUsage']) {
        if (response[key] !== undefined
            && (response[key] === null || typeof response[key] !== 'object' || Array.isArray(response[key]))) {
          return finish(new Error(`Invalid Lisp ProviderResponse: ${key} must be an object`));
        }
      }
      finish(null, response);
    });
    child.stdin.end(JSON.stringify(request));
  });
}

class OpenCodeProvider {
  constructor(options = {}) {
    this.config = options.config || {};
    this.providerId = options.id || 'opencode';
  }

  id() { return this.providerId; }

  async callApi(prompt, context = {}, callOptions = {}) {
    const config = this.config;
    const timeout = config.timeout;
    if (!validTimeout(timeout)) throw new Error('OpenCode provider config.timeout must be an integer from 1 to 86400000 ms');
    const overallTimeout = config.overallTimeoutMs ?? timeout + 30000;
    const maximumDeadline = 24 * 60 * 60 * 1000 + 30000;
    if (!Number.isSafeInteger(overallTimeout) || overallTimeout < timeout
        || overallTimeout > maximumDeadline) {
      throw new Error('OpenCode provider config.overallTimeoutMs must be an integer between config.timeout and 86430000 ms');
    }
    const harness = process.env.SKILL_EVAL_HARNESS_ROOT || path.resolve(__dirname, '../..');
    const request = {
      protocolVersion: 1,
      prompt,
      config,
      vars: context.vars || {},
    };
    return runLisp(harness, request, timeout, overallTimeout, callOptions.abortSignal);
  }
}

module.exports = OpenCodeProvider;
