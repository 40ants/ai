// ADR 0001: transport only. Collection, grading and statistics live in Lisp.
const path = require('node:path');
const { spawn } = require('node:child_process');

module.exports = async function lispAssertion(output, context) {
  const response = context.providerResponse;
  if (!response?.metadata) throw new Error('Missing native provider metadata');
  const harness = process.env.SKILL_EVAL_HARNESS_ROOT || path.resolve(__dirname, '../..');
  const request = {
    protocolVersion: 1, output, runDir: process.env.SKILL_EVAL_RUN_DIR,
    context: {
      prompt: context.prompt, vars: context.vars,
      provider: { label: context.provider.label },
      providerResponse: {
        metadata: response.metadata, raw: response.raw,
        sessionId: response.sessionId, tokenUsage: response.tokenUsage,
      },
    },
  };
  try {
    const timeout = Number(process.env.SKILL_EVAL_ADAPTER_TIMEOUT_MS || 60000);
    if (!Number.isFinite(timeout) || timeout < 1 || timeout > 60000) {
      throw new Error('Adapter timeout must be 1..60000 ms');
    }
    const answer = await new Promise((resolve, reject) => {
      const child = spawn('ros', ['-Q', '--', path.join(harness, 'roswell/ai-evals.ros'), 'assert'], {
        cwd: harness, env: process.env, shell: false, detached: true,
        stdio: ['pipe', 'pipe', 'pipe'],
      });
      let stdout = '', stderr = '', settled = false;
      const finish = (error, value) => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        if (error && child.pid) {
          try { process.kill(-child.pid, 'SIGKILL'); } catch { /* Already exited. */ }
        }
        error ? reject(error) : resolve(value);
      };
      const timer = setTimeout(() => finish(new Error(`Lisp assertion timeout (${timeout}ms)`)), timeout);
      child.on('error', error => finish(error));
      child.stdin.on('error', error => finish(error));
      child.stdout.setEncoding('utf8');
      child.stderr.setEncoding('utf8');
      child.stdout.on('data', chunk => {
        stdout += chunk;
        if (stdout.length > 8 * 1024 * 1024) finish(new Error('Lisp response exceeds 8 MiB'));
      });
      child.stderr.on('data', chunk => { stderr = (stderr + chunk).slice(-8192); });
      child.on('close', code => {
        if (settled) return;
        if (code !== 0) return finish(new Error(`Lisp assertion exited ${code}: ${stderr}`));
        try { finish(null, JSON.parse(stdout)); }
        catch { finish(new Error(`Invalid Lisp protocol JSON: ${stdout.slice(0, 200)}`)); }
      });
      child.stdin.end(JSON.stringify(request));
    });
    if (answer.protocolVersion === 1 && typeof answer.infrastructureError === 'string'
        && typeof answer.sample?.sampleId === 'string') {
      response.metadata.skillEval = answer.sample;
      throw new Error(answer.infrastructureError);
    }
    if (answer.protocolVersion !== 1 || typeof answer.grading?.pass !== 'boolean'
        || !Number.isFinite(answer.grading.score) || answer.grading.score < 0
        || answer.grading.score > 1 || typeof answer.grading.reason !== 'string'
        || typeof answer.sample?.sampleId !== 'string') {
      throw new Error('Invalid Lisp protocol response schema');
    }
    response.metadata.skillEval = answer.sample;
    return answer.grading;
  } catch (error) {
    response.metadata.skillEval = {
      ...response.metadata.skillEval,
      variant: context.provider.label, infrastructureError: error.message,
    };
    throw error;
  }
};
