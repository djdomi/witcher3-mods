@echo off
REM Unlimited Potions & Decoctions - Installer
REM Alles aus diesem Ordner in den Witcher-3-Spielordner kopieren, dann hier doppelklicken.
if not exist "bin\config\r4game\user_config_matrix\pc" (
  echo FEHLER: Bitte diese Datei in den Witcher-3-Spielordner legen.
  pause
  exit /b 1
)
for %%F in (dx11filelist.txt dx12filelist.txt) do (
  findstr /C:"modUnlimitedPotions.xml" "bin\config\r4game\user_config_matrix\pc\%%F" >nul 2>&1 || echo modUnlimitedPotions.xml;>>"bin\config\r4game\user_config_matrix\pc\%%F"
)
echo Fertig! Spiel starten: Optionen ^> Mods ^> Cheats
pause
