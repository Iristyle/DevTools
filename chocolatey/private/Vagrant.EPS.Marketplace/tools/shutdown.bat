ECHO OFF
cd /d %~dp0

for /f "tokens=2* delims= " %%F IN ('vagrant status ^| find /I "default"') DO (SET "STATE=%%F%%G")

IF "%STATE%" EQU "running" (
  ECHO Safely Suspending Vagrant VM: EPS.Marketplace...
  vagrant suspend
)
