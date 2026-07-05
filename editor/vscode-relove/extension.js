const fs = require('fs');
const path = require('path');
const vscode = require('vscode');

let diagnostics;
let statusBar;
let watchers = [];
const folderDiagnosticUris = new Map();

function activate(context) {
  diagnostics = vscode.languages.createDiagnosticCollection('relove');
  statusBar = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 100);
  statusBar.command = 'relove.refreshStatus';
  statusBar.text = 'relove: watching';
  statusBar.show();

  context.subscriptions.push(diagnostics, statusBar);
  context.subscriptions.push(vscode.commands.registerCommand('relove.refreshStatus', refreshAll));
  context.subscriptions.push(vscode.commands.registerCommand('relove.clearDiagnostics', clearDiagnostics));

  startWatchers(context);
  refreshAll();
}

function deactivate() {
  clearDiagnostics();
  watchers.forEach((watcher) => watcher.dispose());
  watchers = [];
}

function startWatchers(context) {
  const folders = vscode.workspace.workspaceFolders || [];

  folders.forEach((folder) => {
    const pattern = new vscode.RelativePattern(folder, '.relove/status.json');
    const watcher = vscode.workspace.createFileSystemWatcher(pattern);

    watcher.onDidCreate(() => refreshWorkspace(folder));
    watcher.onDidChange(() => refreshWorkspace(folder));
    watcher.onDidDelete(() => {
      clearFolderDiagnostic(folder);
      statusBar.text = 'relove: no status';
    });

    watchers.push(watcher);
    context.subscriptions.push(watcher);
  });
}

function refreshAll() {
  const folders = vscode.workspace.workspaceFolders || [];

  if (folders.length === 0) {
    statusBar.text = 'relove: no workspace';
    diagnostics.clear();
    return;
  }

  folders.forEach(refreshWorkspace);
}

function refreshWorkspace(folder) {
  const statusPath = path.join(folder.uri.fsPath, '.relove', 'status.json');

  if (!fs.existsSync(statusPath)) {
    statusBar.text = 'relove: no status';
    return;
  }

  let status;
  try {
    status = JSON.parse(fs.readFileSync(statusPath, 'utf8'));
  } catch (error) {
    statusBar.text = 'relove: bad status json';
    return;
  }

  applyStatus(folder, status);
}

function applyStatus(folder, status) {
  if (!status || !status.status) {
    statusBar.text = 'relove: unknown';
    return;
  }

  if (status.status === 'error') {
    statusBar.text = 'relove: error';
    publishDiagnostic(folder, status);
    return;
  }

  if (status.status === 'restart_required') {
    statusBar.text = 'relove: restart required';
    publishDiagnostic(folder, {
      ...status,
      severity: 'warning',
    });
    return;
  }

  clearFolderDiagnostic(folder);
  statusBar.text = `relove: ${status.status}`;
}

function clearFolderDiagnostic(folder) {
  const previous = folderDiagnosticUris.get(folder.uri.fsPath);
  if (previous) {
    diagnostics.delete(previous);
    folderDiagnosticUris.delete(folder.uri.fsPath);
  }
}

function publishDiagnostic(folder, status) {
  const file = status.file || 'main.lua';
  const absolutePath = path.isAbsolute(file) ? file : path.join(folder.uri.fsPath, file);

  // status.file may be a callback label ("love.update") rather than a real path
  // for runtime errors; don't attach a diagnostic to a file that doesn't exist.
  if (!fs.existsSync(absolutePath)) {
    return;
  }

  const uri = vscode.Uri.file(absolutePath);
  const line = Math.max(0, Number(status.line || extractLine(status.message) || 1) - 1);
  const range = new vscode.Range(line, 0, line, 200);
  const severity = status.severity === 'warning'
    ? vscode.DiagnosticSeverity.Warning
    : vscode.DiagnosticSeverity.Error;
  const message = status.message || status.status;
  const diagnostic = new vscode.Diagnostic(range, message, severity);

  diagnostic.source = 'relove';
  diagnostic.code = status.usingLastGood ? 'using-last-good' : undefined;

  const frames = parseStackFrames(status.stack, folder);
  if (frames.length) {
    diagnostic.relatedInformation = frames;
  }

  clearFolderDiagnostic(folder);
  folderDiagnosticUris.set(folder.uri.fsPath, uri);
  diagnostics.set(uri, [diagnostic]);
}

// Turn a Lua traceback (status.stack) into clickable related-information entries,
// one per stack frame that resolves to a real file. Newest frame first.
function parseStackFrames(stack, folder) {
  if (!stack) {
    return [];
  }

  const frames = [];
  const seen = new Set();
  const framePattern = /([\w\-./]+\.lua):(\d+)/;

  for (const rawLine of String(stack).split('\n')) {
    // The unanchored pattern backtracks quadratically on a long run of path-like
    // characters; a genuine traceback frame is short, so skip pathological lines.
    if (rawLine.length > 2048) {
      continue;
    }

    const match = rawLine.match(framePattern);
    if (!match) {
      continue;
    }

    const file = match[1];
    const lineNumber = Math.max(0, Number(match[2]) - 1);
    const absolutePath = path.isAbsolute(file) ? file : path.join(folder.uri.fsPath, file);
    const key = `${absolutePath}:${lineNumber}`;

    if (seen.has(key) || !fs.existsSync(absolutePath)) {
      continue;
    }
    seen.add(key);

    const location = new vscode.Location(
      vscode.Uri.file(absolutePath),
      new vscode.Range(lineNumber, 0, lineNumber, 200)
    );
    frames.push(new vscode.DiagnosticRelatedInformation(location, rawLine.trim() || `${file}:${lineNumber + 1}`));

    if (frames.length >= 12) {
      break;
    }
  }

  return frames;
}

function extractLine(message) {
  if (!message) {
    return null;
  }

  const match = String(message).match(/:(\d+):/);
  return match ? Number(match[1]) : null;
}

function clearDiagnostics() {
  if (diagnostics) {
    diagnostics.clear();
  }

  folderDiagnosticUris.clear();

  if (statusBar) {
    statusBar.text = 'relove: cleared';
  }
}

module.exports = {
  activate,
  deactivate,
  parseStackFrames,
};
