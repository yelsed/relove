# relove installer for Windows PowerShell (parallels install.sh).
#
#   irm https://raw.githubusercontent.com/yelsed/relove/master/install.ps1 | iex
#
# Environment overrides:
#   RELOVE_VERSION   git tag to install, e.g. v0.1.0 (default: master)
#   RELOVE_PREFIX    where the runtime is placed   (default: %LOCALAPPDATA%\relove)
#   RELOVE_BIN       where the relove.cmd wrapper goes (default: <prefix>\bin)

$ErrorActionPreference = 'Stop'

$repo    = 'yelsed/relove'
$version = if ($env:RELOVE_VERSION) { $env:RELOVE_VERSION } else { 'master' }
$prefix  = if ($env:RELOVE_PREFIX)  { $env:RELOVE_PREFIX }  else { Join-Path $env:LOCALAPPDATA 'relove' }
$bin     = if ($env:RELOVE_BIN)     { $env:RELOVE_BIN }     else { Join-Path $prefix 'bin' }

# LÖVE ships luajit, so a game machine often has luajit but no standalone lua.
$lua = $null
foreach ($candidate in 'lua', 'luajit') {
    if (Get-Command $candidate -ErrorAction SilentlyContinue) { $lua = $candidate; break }
}
if (-not $lua) { throw 'relove: need lua or luajit on PATH (LÖVE ships luajit).' }

if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
    throw 'relove: need tar on PATH (ships with Windows 10 1803+).'
}

$url = if ($version -eq 'master') {
    "https://github.com/$repo/archive/refs/heads/master.tar.gz"
} else {
    "https://github.com/$repo/archive/refs/tags/$version.tar.gz"
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("relove-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    $archive = Join-Path $tmp 'relove.tar.gz'
    Write-Host "relove: downloading $url"
    Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing

    tar -xzf $archive -C $tmp
    $src = Get-ChildItem -Path $tmp -Directory -Filter 'relove-*' | Select-Object -First 1
    if (-not $src) { throw 'relove: unexpected archive layout.' }

    New-Item -ItemType Directory -Path $prefix, $bin -Force | Out-Null
    foreach ($dir in 'dev', 'tools') {
        $dest = Join-Path $prefix $dir
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        Copy-Item -Path (Join-Path $src.FullName $dir) -Destination $dest -Recurse
    }

    $wrapper = Join-Path $bin 'relove.cmd'
    @(
        '@echo off'
        "set `"RELOVE_RUNTIME=$prefix`""
        "$lua `"$prefix\tools\relove.lua`" %*"
    ) | Set-Content -Path $wrapper -Encoding ASCII

    Write-Host "relove: installed $wrapper (runtime in $prefix, interpreter $lua)"
    if (($env:PATH -split ';') -notcontains $bin) {
        Write-Host "relove: add $bin to your PATH:"
        Write-Host "  setx PATH `"$bin;%PATH%`""
    }
}
finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
