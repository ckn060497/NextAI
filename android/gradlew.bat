@echo off
setlocal
set GRADLE_VERSION=8.10.2
if "%GRADLE_USER_HOME%"=="" set GRADLE_USER_HOME=%USERPROFILE%\.gradle
set DIST=%GRADLE_USER_HOME%\nexus-ai-gradle\%GRADLE_VERSION%\gradle-%GRADLE_VERSION%
if exist "%DIST%\bin\gradle.bat" goto run
set ROOT=%GRADLE_USER_HOME%\nexus-ai-gradle\%GRADLE_VERSION%
if not exist "%ROOT%" mkdir "%ROOT%"
set ZIP=%ROOT%\gradle.zip
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing 'https://services.gradle.org/distributions/gradle-%GRADLE_VERSION%-bin.zip' -OutFile '%ZIP%'"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Force '%ZIP%' '%ROOT%'"
del /q "%ZIP%"
:run
call "%DIST%\bin\gradle.bat" %*
endlocal
