// VS Code extension parseStackFrames test (M3). Run: node test/vscode_extension.js
const Module = require('module');
const fs = require('fs');
const path = require('path');
const os = require('os');

const fakeVscode = {
  Uri: { file: (p) => ({ fsPath: p }) },
  Range: class { constructor(sl, sc, el, ec) { this.startLine = sl; this.sc = sc; this.el = el; this.ec = ec; } },
  Location: class { constructor(uri, range) { this.uri = uri; this.range = range; } },
  DiagnosticRelatedInformation: class { constructor(location, message) { this.location = location; this.message = message; } },
  Diagnostic: class {}, DiagnosticSeverity: { Error: 0, Warning: 1 },
  languages: { createDiagnosticCollection: () => ({}) },
  window: { createStatusBarItem: () => ({ show() {} }) },
  StatusBarAlignment: { Left: 1 },
  workspace: { workspaceFolders: [] },
  commands: { registerCommand: () => ({}) },
};

const origLoad = Module._load;
Module._load = function (request, parent, isMain) {
  if (request === 'vscode') return fakeVscode;
  return origLoad(request, parent, isMain);
};

const ext = require(path.join(__dirname, '..', 'editor', 'vscode-relove', 'extension.js'));

let PASS = 0, FAIL = 0;
const check = (name, cond) => { if (cond) { PASS++; console.log('  ok   : ' + name); } else { FAIL++; console.log('  FAIL : ' + name); } };

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'relove-ext-'));
fs.mkdirSync(path.join(dir, 'src'), { recursive: true });
fs.writeFileSync(path.join(dir, 'main.lua'), 'x');
fs.writeFileSync(path.join(dir, 'src', 'game.lua'), 'y');
const folder = { uri: { fsPath: dir } };

const stack = [
  "src/game.lua:12: attempt to index a nil value",
  "stack traceback:",
  "\tsrc/game.lua:12: in function 'update'",
  "\tmain.lua:5: in function <main.lua:4>",
  "\tnope/missing.lua:99: in main chunk",
  "\t[C]: in ?",
].join('\n');

const frames = ext.parseStackFrames(stack, folder);
check('produced frames', frames.length > 0);
check('skips non-existent file (missing.lua)', !frames.some(f => f.location.uri.fsPath.includes('missing.lua')));
check('includes src/game.lua frame', frames.some(f => f.location.uri.fsPath.endsWith(path.join('src', 'game.lua'))));
check('includes main.lua frame', frames.some(f => f.location.uri.fsPath.endsWith('main.lua')));
check('line converted 1-based -> 0-based (12 -> 11)', frames.some(f => f.location.range.startLine === 11));
check('dedups repeated src/game.lua:12', frames.filter(f => f.location.uri.fsPath.endsWith(path.join('src', 'game.lua')) && f.location.range.startLine === 11).length === 1);
check('empty stack -> no frames', ext.parseStackFrames('', folder).length === 0);
check('nil stack -> no frames', ext.parseStackFrames(undefined, folder).length === 0);
check('message carries the frame text', frames.some(f => typeof f.message === 'string' && f.message.includes('game.lua:12')));

const longStack = 'x'.repeat(60000) + '\n\tsrc/game.lua:7: in function <x>';
const t0 = Date.now();
const f2 = ext.parseStackFrames(longStack, folder);
const elapsedMs = Date.now() - t0;
check(`long line does not hang (${elapsedMs}ms < 200)`, elapsedMs < 200);
check('real frame after a long line still parsed', f2.some(f => f.location.range.startLine === 6));

fs.rmSync(dir, { recursive: true, force: true });
Module._load = origLoad;
console.log(`\n=== vscode_extension: ${PASS} passed, ${FAIL} failed ===`);
process.exit(FAIL === 0 ? 0 : 1);
