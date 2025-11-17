@echo off
REM 設置 Gradle 緩存目錄到 E 槽
set GRADLE_USER_HOME=E:\.gradle

REM 切換到前端目錄
cd /d "%~dp0"

REM 運行 Flutter
flutter run

