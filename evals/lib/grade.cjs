const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const symbol = node => node && typeof node === 'object' && !Array.isArray(node) ? node.s : undefined;
const isForm = (node, name) => Array.isArray(node) && symbol(node[0]) === name;
function walk(node, visit) {
  visit(node);
  if (Array.isArray(node)) for (const child of node) walk(child, visit);
}
function grade(output, context) {
  const v = context.vars;
  let result;
  try { result = typeof output === 'string' ? JSON.parse(output) : output; }
  catch { return { pass: false, score: 0, reason: 'Provider returned malformed evidence JSON' }; }
  const checks = [];
  const check = (name, pass) => checks.push({ name, pass: !!pass });
  if (!result || typeof result.files !== 'object' || typeof result.skillRead !== 'boolean') {
    return { pass: false, score: 0, reason: 'Missing files/skill-read evidence' };
  }
  // Ablation still measures results; activation is meaningful only when the
  // skill was made available to the agent.
  if (result.variant !== 'without-skill') check('skill-read', result.skillRead === v.shouldTrigger);
  for (const [file, content] of Object.entries(v.fixtures || {})) {
    if (file === 'AGENTS.md' || file === v.protected) check(`preserved:${file}`, result.files[file] === content);
  }
  if (v.noChanges) check('no-changes', JSON.stringify(result.files) === JSON.stringify(v.fixtures || {}));
  if (v.textFile) check('text-output', typeof result.files[v.textFile] === 'string' && result.files[v.textFile].includes(v.textContains));
  if (v.file) {
    const source = result.files[v.file];
    check('target-file', typeof source === 'string' && source.length > 0);
    if (source) {
      if (v.sourceOnly) check('scope', Object.keys(result.files).every(f => f === v.file || f in (v.fixtures || {})));
      check('no-tabs', !source.includes('\t'));
      check('100-columns', source.split('\n').every(line => line.length <= 100));
      const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'cl-grader-'));
      try {
        const candidate = path.join(scratch, 'candidate.lisp');
        fs.writeFileSync(candidate, source);
        const processResult = spawnSync('sbcl', ['--script', path.join(__dirname, 'check-lisp.lisp'), candidate, v.package, v.runtime], {
          encoding: 'utf8', timeout: 20000, maxBuffer: 4 * 1024 * 1024, cwd: scratch
        });
        const line = processResult.stdout?.split('\n').find(l => l.startsWith('EVAL_JSON:'));
        if (processResult.error || processResult.status !== 0 || !line) {
          throw new Error(`SBCL grader infrastructure: ${processResult.error?.message || processResult.stderr?.slice(-500)}`);
        } else {
          const evidence = JSON.parse(line.slice('EVAL_JSON:'.length));
          check(`lisp-reader${evidence.readError ? ':' + evidence.readError : ''}`, !evidence.readError);
          check(`functional${evidence.runtimeError ? ':' + evidence.runtimeError : ''}`, !evidence.readError && !evidence.runtimeError);
          const forms = evidence.forms;
          const packageForm = forms.find(f => isForm(f, v.override ? 'defpackage' : 'define-package'));
          check('package-declaration', !!packageForm);
          check('full-package-path', symbol(packageForm?.[1]) === v.package);
          check('uninterned-package-name', packageForm?.[1]?.p === null);
          const inPackage = forms.find(f => isForm(f, 'in-package'));
          check('in-package', symbol(inPackage?.[1]) === v.package);
          const options = packageForm?.slice(2) || [];
          const uses = options.filter(f => isForm(f, 'use'));
          check('namespace-hygiene', uses.length === 1 && uses[0].length === 2 && symbol(uses[0][1]) === 'cl');
          const exports = options.filter(f => isForm(f, 'export')).flatMap(f => f.slice(1).map(symbol));
          check('public-export', exports.includes(v.function));
          const definition = forms.find(f => isForm(f, 'defun') && symbol(f[1]) === v.function);
          check('public-docstring', typeof definition?.[3] === 'string' && definition[3].trim().length > 0);
          const signatures = forms.filter(f => isForm(f, '->') && symbol(f[1]) === v.function);
          check(v.override ? 'override:no-signature' : 'type-signature', v.override ? signatures.length === 0 : signatures.length > 0);
          if (!v.override) {
            const layouts = evidence.signatureLayouts || [];
            check('return-type-layout', !evidence.readError && layouts.length > 0
              && layouts.every(valid => valid === 1));
          }
          const nodes = []; walk(forms, n => nodes.push(n));
          check('no-runtime-eval-intern-unintern', !nodes.some(n => ['eval', 'intern', 'unintern'].includes(symbol(n))));
          const loops = nodes.filter(n => isForm(n, 'loop'));
          const clauses = new Set(['for', 'as', 'in', 'on', 'from', 'to', 'below', 'above', 'by',
            'while', 'until', 'do', 'doing', 'collect', 'collecting', 'sum', 'summing',
            'count', 'counting', 'append', 'nconc', 'when', 'unless', 'if', 'else',
            'finally', 'initially', 'return', 'with', 'repeat', 'thereis', 'always', 'never']);
          check('loop-keyword-style', loops.every(loop => !loop.slice(1).some(n => n?.p === 'KEYWORD' && clauses.has(symbol(n)))));
          if (v.requireLoop) check('loop-present', loops.length > 0);
          if (v.requireExhaustive) check('exhaustive-dispatch', nodes.some(n => isForm(n, 'ecase') || isForm(n, 'etypecase')));
          if (v.requireIgnore) check('ignore-declaration', nodes.some(n => isForm(n, 'ignore') && n.slice(1).some(x => symbol(x) === v.requireIgnore)));
          const errors = nodes.filter(n => isForm(n, 'error') && typeof n[1] === 'string');
          check('error-format-arguments', errors.every(e => e.length >= 3));
          if (v.requireFormattedError) check('formatted-error-present', errors.some(e => e.length >= 3));
          if (v.hook) {
            const variable = forms.find(f => (isForm(f, 'defvar') || isForm(f, 'defparameter')) && symbol(f[1]) === v.hook);
            check('hook-export', exports.includes(v.hook));
            check('hook-docstring', typeof variable?.[3] === 'string' && /ignor|skip/i.test(variable[3]) && /function|funcall/i.test(variable[3]));
          }
        }
      } finally { fs.rmSync(scratch, { recursive: true, force: true }); }
    }
  }
  const failures = checks.filter(c => !c.pass);
  return {
    pass: checks.length > 0 && failures.length === 0,
    score: checks.length ? (checks.length - failures.length) / checks.length : 0,
    reason: failures.length ? failures.map(c => c.name).join('; ') : `${checks.length} checks passed`
  };
}
module.exports = grade;
