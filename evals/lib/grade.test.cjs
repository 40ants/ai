const { test } = require('node:test');
const assert = require('node:assert/strict');
const grade = require('./grade.cjs');

const signature = `(-> add-score (integer integer)
    (values integer &optional))`;
const source = `;;;; Scores.
(uiop:define-package #:demo/src/models/score
  (:use #:cl)
  (:import-from #:serapeum #:->)
  (:export #:add-score))
(in-package #:demo/src/models/score)

${signature}
(defun add-score (a b)
  "Return the sum of the two integer scores."
  (+ a b))
`;
const vars = {
  id: 'package-path', shouldTrigger: true, file: 'src/models/score.lisp',
  package: 'demo/src/models/score', function: 'add-score', runtime: 'add-score'
};
function evaluate(code, extra = {}) {
  return grade(JSON.stringify({ variant: 'with-skill', skillRead: true,
    files: { [vars.file]: code }, ...extra }), { vars });
}
test('known-good source passes the actual reader, runtime and contract checks', () => {
  const result = evaluate(source);
  assert.equal(result.pass, true, result.reason);
});
test('a wrong function with all the right style words still fails', () => {
  const result = evaluate(source.replace('(+ a b)', '(- a b)'));
  assert.equal(result.pass, false);
  assert.match(result.reason, /functional/);
});
test('dropping src from a package path fails', () => {
  assert.equal(evaluate(source.replaceAll('demo/src/', 'demo/')).pass, false);
});
test('DEFPACKAGE fails the normal package convention', () => {
  assert.equal(evaluate(source.replace('uiop:define-package', 'defpackage')).pass, false);
});
test('an absent signature fails even when the source mentions it in a comment', () => {
  const code = source.replace(signature, '; -> add-score');
  assert.equal(evaluate(code).pass, false);
});
test('a missing export fails', () => {
  assert.equal(evaluate(source.replace('(:export #:add-score)', '(:export)')).pass, false);
});
test('a missing docstring fails', () => {
  assert.equal(evaluate(source.replace('  "Return the sum of the two integer scores."\n', '')).pass, false);
});
test('an unsuccessful skill read fails activation evidence', () => {
  assert.equal(evaluate(source, { skillRead: false }).pass, false);
});
test('extra scaffolding is rejected only when the task explicitly forbids it', () => {
  const output = { variant: 'with-skill', skillRead: true,
    files: { [vars.file]: source, 'demo.asd': '(asdf:defsystem "demo")' } };
  assert.equal(grade(JSON.stringify(output), { vars }).pass, true);
  assert.equal(grade(JSON.stringify(output), { vars: { ...vars, sourceOnly: true } }).pass, false);
});
test('a project override accepts DEFPACKAGE and no Serapeum signature', () => {
  const code = source.replace('uiop:define-package', 'defpackage')
    .replace(signature, '');
  const result = grade(JSON.stringify({ variant: 'with-skill', skillRead: true, files: { [vars.file]: code } }),
    { vars: { ...vars, override: true } });
  assert.equal(result.pass, true, result.reason);
});
test('protected dependency: unchanged passes, an actual edit fails', () => {
  const v = { shouldTrigger: true, protected: '.qlot/vendor/x.lisp', noChanges: true,
    fixtures: { '.qlot/vendor/x.lisp': '(print "helo")' } };
  const result = files => grade(JSON.stringify({ variant: 'with-skill', skillRead: true, files }), { vars: v });
  assert.equal(result(v.fixtures).pass, true);
  assert.equal(result({ '.qlot/vendor/x.lisp': '(print "hello")' }).pass, false);
});
test('negative routing: selecting the Lisp skill for Python fails', () => {
  const output = { variant: 'with-skill', skillRead: false, files: { 'hello.py': 'print("hello")' } };
  const context = { vars: { shouldTrigger: false, textFile: 'hello.py', textContains: 'hello' } };
  assert.equal(grade(JSON.stringify(output), context).pass, true);
  assert.equal(grade(JSON.stringify({ ...output, skillRead: true }), context).pass, false);
});
test('empty/malformed provider evidence never passes', () => {
  assert.equal(grade('not json', { vars }).pass, false);
  assert.equal(grade('{}', { vars }).pass, false);
});

test('return type on the signature header line fails the layout assertion', () => {
  const result = evaluate(source.replace(signature, signature.replace('\n    ', ' ')));
  assert.equal(result.pass, false);
  assert.equal(result.reason, 'return-type-layout');
});
test('return type needs exactly four spaces, not tabs or other indentation', () => {
  for (const indent of ['', '  ', '   ', '     ', '        ', '\t']) {
    const result = evaluate(source.replace('\n    (values', '\n' + indent + '(values'));
    assert.equal(result.pass, false, JSON.stringify(indent));
    assert.match(result.reason, /return-type-layout/, JSON.stringify(indent));
  }
});
test('qualified Serapeum signatures and scalar return types pass', () => {
  const code = source.replace('(-> add-score', '(serapeum:-> add-score');
  assert.equal(evaluate(code).pass, true);
  assert.equal(evaluate(code.replace('(values integer &optional)', 'integer')).pass, true);
});
test('macro identity is preserved through a package re-export', () => {
  const alias = '(cl:defpackage #:signature-alias (:use) (:import-from #:serapeum #:->) (:export #:->))\n';
  const code = alias + source.replace('(-> add-score', '(signature-alias:-> add-score');
  const result = evaluate(code);
  assert.equal(result.pass, true, result.reason);
});
test('correct examples in comments or docstrings cannot hide an inline signature', () => {
  const inline = source.replace(signature, signature.replace('\n    ', ' '));
  for (const code of [
    '; Example:\n' + signature.split('\n').map(line => '; ' + line).join('\n') + '\n' + inline,
    '#| Example #| nested comment |#\n' + signature + '\n|#\n' + inline,
    inline.replace('Return the sum of the two integer scores.', signature)
  ]) {
    assert.equal(evaluate(code).reason, 'return-type-layout');
  }
});
test('nested and multiline argument types keep the correct return-type boundary', () => {
  const code = source.replace('(integer integer)', '((integer * *)\n                 integer)');
  assert.equal(evaluate(code).pass, true);
});
test('reader comments between argument and return types are skipped', () => {
  const code = source.replace('\n    (values', ' ; argument types\n  #| nested #| comment |# |#\n    (values');
  assert.equal(evaluate(code).pass, true);
  assert.equal(evaluate(code.replace('\n    (values', '\n  (values')).reason, 'return-type-layout');
});
test('layout applies to helper signatures too, including zero-argument functions', () => {
  const helper = '\n(serapeum:-> default-score ()\n    (values integer &optional))\n(defun default-score () 0)\n';
  assert.equal(evaluate(source + helper).pass, true);
  assert.equal(evaluate(source + helper.replace('\n    (values', ' (values')).reason, 'return-type-layout');
});
test('Unicode text before a signature does not shift its source positions', () => {
  const code = source.replace(';;;; Scores.', ';;;; Суммы 🧮.');
  assert.equal(evaluate(code).pass, true);
});
