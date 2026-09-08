@echo off
setlocal EnableExtensions
title Shutdown / Reboot / Process Scheduler

:MODE
cls
echo ================================================
echo      SHUTDOWN / REBOOT / PROCESS SCHEDULER
echo ================================================
echo.
echo    [1] Shutdown
echo    [2] Reboot
echo    [3] Cancel timer
echo    [4] Process shutdown
echo    [0] Exit
echo.
set "KILLARGS="
set "KLIST="
set "MODE="
set /p "MODE=Select: "

if "%MODE%"=="1" goto SET_SHUTDOWN
if "%MODE%"=="2" goto SET_REBOOT
if "%MODE%"=="3" goto CANCEL
if "%MODE%"=="4" goto SET_PKILL
if "%MODE%"=="0" exit /b 0
goto MODE

:SET_SHUTDOWN
set "ACTION=/s"
set "ACTION_NAME=SHUTDOWN"
goto DELAY

:SET_REBOOT
set "ACTION=/r"
set "ACTION_NAME=REBOOT"
goto DELAY

:CANCEL
shutdown /a >nul 2>&1
if errorlevel 1 goto NOTHING_TO_CANCEL
echo.
echo Timer cancelled. No shutdown or reboot is pending.
goto END

:NOTHING_TO_CANCEL
echo.
echo No timer is running - nothing to cancel.
goto END

:SET_PKILL
cls
echo ================================================
echo                PROCESS SHUTDOWN
echo ================================================
echo.
echo    Match the process by:
echo.
echo    [1] Image name    e.g. Spotify.exe
echo    [2] Publisher     e.g. Spotify AB
echo    [3] PID           e.g. 21840
echo    [0] back
echo.
set "PK="
set /p "PK=Select: "

if "%PK%"=="1" goto PK_NAME
if "%PK%"=="2" goto PK_PUB
if "%PK%"=="3" goto PK_PID
if "%PK%"=="0" goto MODE
goto SET_PKILL

:PK_NAME
echo.
set "KVAL="
set /p "KVAL=Image name: "
call :SANITIZE
if not defined KVAL goto PK_NAME
echo.
tasklist /FI "IMAGENAME eq %KVAL%"
tasklist /FI "IMAGENAME eq %KVAL%" /NH | findstr /i /c:"%KVAL%" >nul || call :NOT_RUNNING
if not defined KVAL goto SET_PKILL
set "KILLARGS=/IM "%KVAL%""
set "KLIST=%KVAL%"
set "ACTION_NAME=KILL image %KVAL%"
goto DELAY

:NOT_RUNNING
echo.
echo   Nothing with that name is running right now.
set "OK="
set /p "OK=Schedule anyway? [Y/N]: "
if /i not "%OK%"=="Y" set "KVAL="
goto :eof

:PK_PID
echo.
set "KVAL="
set /p "KVAL=PID: "
rem  set /a reads KVAL by name, so its text never reaches a command line
set "KPID=0"
set /a KPID=KVAL 2>nul
if %KPID% LSS 1 goto PK_PID
tasklist /FI "PID eq %KPID%" /NH | findstr /r /c:"[0-9]" >nul || goto PK_PID_NONE
echo.
tasklist /FI "PID eq %KPID%"
set "KNAME=?"
for /f "tokens=1 delims=," %%p in ('tasklist /FI "PID eq %KPID%" /NH /FO CSV') do set "KNAME=%%~p"
set "KILLARGS=/PID %KPID%"
set "KLIST=PID %KPID% - %KNAME%"
set "ACTION_NAME=KILL PID %KPID% - %KNAME%"
goto DELAY

:PK_PID_NONE
echo.
echo   No process is running with PID %KPID%.
goto PK_PID

:PK_PUB
echo.
set "KVAL="
set /p "KVAL=Publisher: "
call :SANITIZE
if not defined KVAL goto PK_PUB
echo.
echo   Scanning running processes...
set "KCNT=0"
set "KILLARGS="
set "KLIST="
for /f "usebackq delims=" %%n in (`powershell -NoProfile -Command "$ErrorActionPreference='SilentlyContinue';$c=@{};$r=@();$skip=@('csrss.exe','wininit.exe','winlogon.exe','services.exe','lsass.exe','smss.exe','System','Registry','System Idle Process');foreach($x in (Get-CimInstance Win32_Process)){$p=$x.ExecutablePath;if(-not $p){continue};if($skip -contains $x.Name){continue};if(-not $c.ContainsKey($p)){$s='';try{$s=[Security.Cryptography.X509Certificates.X509Certificate]::CreateFromSignedFile($p).Subject}catch{};$c[$p]=[string][Diagnostics.FileVersionInfo]::GetVersionInfo($p).CompanyName+'~'+$s};if($c[$p] -like '*%KVAL%*'){if($r -notcontains $x.Name){$r+=$x.Name}}};foreach($n in $r){$n}" 2^>nul`) do call :ADDIM "%%n"
if "%KCNT%"=="0" goto PK_PUB_NONE
echo.
echo   Matched %KCNT% image name^(s^): %KLIST%
set "ACTION_NAME=KILL publisher %KVAL%"
goto DELAY

:PK_PUB_NONE
echo.
echo   Nothing running matches publisher "%KVAL%".
echo   Publisher is matched against the file's CompanyName and its
echo   signing certificate. Try a shorter fragment, e.g. Spotify.
goto PK_PUB

:ADDIM
set /a KCNT+=1
set "KILLARGS=%KILLARGS% /IM "%~1""
set "KLIST=%KLIST%%~1  "
goto :eof

:SANITIZE
rem  strip shell/PowerShell metacharacters, then whitelist what is left
if not defined KVAL goto :eof
set "KVAL=%KVAL:"=%"
set "KVAL=%KVAL:^=%"
set "KVAL=%KVAL:&=%"
set "KVAL=%KVAL:|=%"
set "KVAL=%KVAL:<=%"
set "KVAL=%KVAL:>=%"
set "KVAL=%KVAL:'=%"
if not defined KVAL goto :eof
echo(%KVAL%|findstr /r /c:"^[A-Za-z0-9][A-Za-z0-9 ._-]*$" >nul || set "KVAL="
if not defined KVAL echo   Invalid value - use letters, digits, space, dot, underscore, dash.
goto :eof

:DELAY
cls
echo ================================================
echo    %ACTION_NAME% - in how much time?
echo ================================================
echo.
echo    [1]  15 minutes        [7]  3 hours
echo    [2]  30 minutes        [8]  4 hours
echo    [3]  45 minutes        [9]  5 hours
echo    [4]  1 hour            [10] 8 hours
echo    [5]  1.5 hours         [11] custom time
echo    [6]  2 hours           [0]  back
echo.
set "SEC="
set "PICK="
set /p "PICK=Select: "

if "%PICK%"=="0"  goto MODE
if "%PICK%"=="1"  set "SEC=900"
if "%PICK%"=="2"  set "SEC=1800"
if "%PICK%"=="3"  set "SEC=2700"
if "%PICK%"=="4"  set "SEC=3600"
if "%PICK%"=="5"  set "SEC=5400"
if "%PICK%"=="6"  set "SEC=7200"
if "%PICK%"=="7"  set "SEC=10800"
if "%PICK%"=="8"  set "SEC=14400"
if "%PICK%"=="9"  set "SEC=18000"
if "%PICK%"=="10" set "SEC=28800"
if "%PICK%"=="11" goto CUSTOM
if not defined SEC goto DELAY
goto CONFIRM

:CUSTOM
echo.
set "MIN="
set /p "MIN=Enter time in minutes: "
rem  set /a reads MIN by name, so non-numeric input collapses to 0 instead
rem  of being re-parsed as a command
set "SEC=0"
set /a SEC=MIN*60 2>nul
if %SEC% LSS 1 goto CUSTOM
if %SEC% GTR 315360000 goto CUSTOM
goto CONFIRM

:CONFIRM
set "AT=unknown"
for /f "delims=" %%t in ('powershell -NoProfile -Command "(Get-Date).AddSeconds(%SEC%).ToString('HH:mm:ss  dd.MM.yyyy')" 2^>nul') do set "AT=%%t"
set /a MM=SEC/60
echo.
echo ------------------------------------------------
echo   Action  : %ACTION_NAME%
if defined KLIST echo   Targets : %KLIST%
echo   Delay   : %MM% min ^(%SEC% sec^)
echo   Fires at: %AT%
echo ------------------------------------------------
echo.
set "OK="
set /p "OK=Confirm? [Y/N]: "
if /i not "%OK%"=="Y" goto MODE

if defined KILLARGS goto RUN_KILL

shutdown %ACTION% /t %SEC%
if errorlevel 1 goto FAILED
echo.
echo Scheduled. To cancel: run this file again and pick [3],
echo or run in a console:  shutdown /a
goto END

:RUN_KILL
if %SEC% GTR 99999 goto KILL_TOOLONG
start "Kill %KLIST% @ %AT%" cmd /s /c "timeout /t %SEC% /nobreak && taskkill /F %KILLARGS% & timeout /t 20 /nobreak >nul"
echo.
echo Scheduled in its own countdown window.
echo To cancel: close that window, or press Ctrl+C in it.
goto END

:KILL_TOOLONG
echo.
echo A process timer cannot exceed 99999 seconds ^(about 27 hours^).
echo Pick a shorter delay.
echo.
pause
goto DELAY

:FAILED
echo.
echo Failed to schedule. An action may already be pending -
echo cancel it first via option [3].

:END
echo.
pause
endlocal
exit /b 0
