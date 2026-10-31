const { test } = require('node:test');
const assert = require('node:assert/strict');
const grade = require('./grade.cjs');

const source = `;;;; Scores.
(uiop:define-package #:demo/src/models/score
  (:use #:cl)
  (:import-from #:serapeum #:->)
  (:export #:add-score))
(in-package #:demo/src/models/score)

(-> add-score (integer integer) (values integer &optional))
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
  const code = source.replace('(-> add-score (integer integer) (values integer &optional))', '; -> add-score');
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
    .replace('(-> add-score (integer integer) (values integer &optional))', '');
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
