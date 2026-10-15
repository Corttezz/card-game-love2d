@echo off
rem Lancador do MODO CHEAT (so em DEV): abre o jogo normal com o painel de cheat (F1).
rem Saves vao para a identidade card-game-cheat, nunca para o save real.
cd /d "%~dp0"
start "" "C:\Program Files\LOVE\love.exe" . cheat
