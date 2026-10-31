const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const grade = require('./workspace-grade.cjs');

test('native workspace evidence is archived before disposal, independently of final prose', () => {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'native-grader-test-'));
  const originalRunDir = process.env.SKILL_EVAL_RUN_DIR;
  try {
    const workspace = path.join(scratch, 'workspace');
    fs.mkdirSync(path.join(workspace, '.git'), { recursive: true });
    fs.mkdirSync(path.join(workspace, '.agents'), { recursive: true });
    fs.writeFileSync(path.join(workspace, 'hello.py'), 'print("hello")\n');
    process.env.SKILL_EVAL_RUN_DIR = path.join(scratch, 'run');
    const metadata = { workingDir: workspace, skillCalls: [] };
    const context = {
      vars: { id: 'negative', shouldTrigger: false, textFile: 'hello.py', textContains: 'hello' },
      provider: { label: 'with-skill' }, prompt: 'Create hello.py',
      providerResponse: { metadata, raw: JSON.stringify({ items: [{ type: 'command_execution' }], usage: { input_tokens: 12, output_tokens: 3 } }) }
    };
    assert.equal(grade('I used writing-common-lisp', context).pass, true);
    assert.equal(metadata.skillEval.skillRead, false);
    assert.equal(metadata.skillEval.commandCount, 1);
    fs.rmSync(workspace, { recursive: true });
    const archived = JSON.parse(fs.readFileSync(path.join(process.env.SKILL_EVAL_RUN_DIR, 'samples', metadata.skillEval.sampleId, 'sample.json')));
    assert.deepEqual(archived.files, { 'hello.py': 'print("hello")\n' });
    metadata.workingDir = path.join(scratch, 'missing');
    assert.throws(() => grade('done', context));
  } finally {
    if (originalRunDir === undefined) delete process.env.SKILL_EVAL_RUN_DIR;
    else process.env.SKILL_EVAL_RUN_DIR = originalRunDir;
    fs.rmSync(scratch, { recursive: true, force: true });
  }
});
