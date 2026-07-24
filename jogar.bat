@echo off
rem Lancador oficial do jogo — SEMPRE roda ESTA copia do projeto,
rem nao importa de onde o .bat for chamado (atalho, taskbar, terminal).
rem Motivo (Jul/2026): `love .` de terminal com CWD errado rodava um
rem snapshot antigo do jogo — semanas de "bug que nao reproduz".
cd /d "%~dp0"
start "" "C:\Program Files\LOVE\love.exe" .
