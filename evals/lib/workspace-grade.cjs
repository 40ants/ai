// Promptfoo owns Codex execution and the disposable workspace. This assertion
// archives files while that workspace still exists, then applies our Lisp rules.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const grade = require('./grade.cjs');

function files(root, prefix = '') {
  const result = {};
  for (const entry of fs.readdirSync(path.join(root, prefix), { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
    if (entry.name === '.agents' || entry.name === '.git') continue;
    const relative = path.posix.join(prefix, entry.name);
    const absolute = path.join(root, relative);
    if (entry.isSymbolicLink()) throw new Error(`Unexpected artifact symlink: ${relative}`);
    if (entry.isDirectory()) Object.assign(result, files(root, relative));
    else {
      if (fs.statSync(absolute).size > 2 * 1024 * 1024) throw new Error(`Artifact too large: ${relative}`);
      result[relative] = fs.readFileSync(absolute, 'utf8');
    }
  }
  return result;
}
module.exports = function workspaceGrade(output, context) {
  const response = context.providerResponse;
  const workspace = response?.metadata?.workingDir;
  const runDir = process.env.SKILL_EVAL_RUN_DIR;
  if (!workspace || !runDir) throw new Error('Missing native workspace metadata or run directory; use evals/run.mjs');
  const variant = context.provider.label;
  const sampleId = `${context.vars.id}-${variant}-${crypto.randomUUID().slice(0, 8)}`;
  const artifactDir = path.join(runDir, 'samples', sampleId);
  fs.mkdirSync(artifactDir, { recursive: true });
  const turn = typeof response.raw === 'string' ? JSON.parse(response.raw) : response.raw;
  if (!Array.isArray(turn?.items)) throw new Error('Missing native Codex turn items');
  const skillRead = (response.metadata.skillCalls || []).some(call => call.name === 'writing-common-lisp');
  const sample = {
    sampleId, variant, files: files(workspace), skillRead,
    commandCount: turn.items.filter(item => item.type === 'command_execution').length,
    usage: turn.usage || {}, final: output,
    trace: path.relative(runDir, path.join(artifactDir, 'turn.json'))
  };
  for (const [relative, content] of Object.entries(sample.files)) {
    const target = path.join(artifactDir, 'files', relative);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, content);
  }
  fs.writeFileSync(path.join(artifactDir, 'turn.json'), JSON.stringify(turn, null, 2));
  fs.writeFileSync(path.join(artifactDir, 'prompt.txt'), context.prompt);
  fs.writeFileSync(path.join(artifactDir, 'sample.json'), JSON.stringify(sample, null, 2));
  // The metadata object is shared with Promptfoo's persisted provider response.
  // The provider's plain-text output stays readable in the viewer.
  const { files: ignoredFiles, ...statistics } = sample;
  response.metadata.skillEval = statistics;
  return grade(sample, context);
};
