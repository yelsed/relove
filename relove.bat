@echo off
rem LÖVE ships luajit, so a game machine often has luajit but no standalone lua.
rem Prefer lua, fall back to luajit.
where lua >nul 2>&1 && (
    lua "%~dp0tools\relove.lua" %*
    exit /b %errorlevel%
)
where luajit >nul 2>&1 && (
    luajit "%~dp0tools\relove.lua" %*
    exit /b %errorlevel%
)
echo relove: need lua or luajit on PATH 1>&2
exit /b 1
