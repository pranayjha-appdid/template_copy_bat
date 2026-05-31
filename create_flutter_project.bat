@echo off
setlocal enabledelayedexpansion

set PROJECT_NAME=%1
set FLUTTER_VERSION=%2
set ORG_NAME=%3

if "%PROJECT_NAME%"=="" (
  echo Usage: create_flutter_project.bat project_name flutter_version org_name
  echo Example: create_flutter_project.bat testtesmplate 3.35.7 com
  echo Example: create_flutter_project.bat football_shuru 3.35.7 in.appdid
  exit /b 1
)

if "%FLUTTER_VERSION%"=="" (
  echo Usage: create_flutter_project.bat project_name flutter_version org_name
  echo Example: create_flutter_project.bat testtesmplate 3.35.7 com
  exit /b 1
)

if "%ORG_NAME%"=="" (
  set ORG_NAME=com
)

set TEMPLATE_REPO=https://github.com/Akash-appdid/flutter-new-updated-getx-template.git
set TEMP_TEMPLATE_DIR=%TEMP%\flutter_template_%RANDOM%%RANDOM%

if exist "%PROJECT_NAME%" (
  echo Error: Folder "%PROJECT_NAME%" already exists.
  echo Delete it first or use another project name.
  exit /b 1
)

where fvm >nul 2>nul
if errorlevel 1 (
  echo Error: fvm not found.
  echo Please install/check FVM first.
  exit /b 1
)

where git >nul 2>nul
if errorlevel 1 (
  echo Error: git not found.
  echo Please install/check Git first.
  exit /b 1
)

echo.
echo Installing Flutter %FLUTTER_VERSION% using FVM...
call fvm install %FLUTTER_VERSION%
if errorlevel 1 exit /b 1

echo.
echo Creating fresh Flutter project...
echo Project name: %PROJECT_NAME%
echo Flutter version: %FLUTTER_VERSION%
echo Org: %ORG_NAME%
call fvm spawn %FLUTTER_VERSION% create --org %ORG_NAME% %PROJECT_NAME%
if errorlevel 1 exit /b 1

echo.
echo Cloning template repo into temp folder...
if exist "%TEMP_TEMPLATE_DIR%" rmdir /s /q "%TEMP_TEMPLATE_DIR%"
git clone --depth 1 %TEMPLATE_REPO% "%TEMP_TEMPLATE_DIR%"
if errorlevel 1 exit /b 1

echo.
echo Copying lib folder...
if exist "%PROJECT_NAME%\lib" rmdir /s /q "%PROJECT_NAME%\lib"
xcopy "%TEMP_TEMPLATE_DIR%\lib" "%PROJECT_NAME%\lib" /E /I /Y
if errorlevel 1 exit /b 1

echo.
echo Copying assets folder...
if exist "%PROJECT_NAME%\assets" rmdir /s /q "%PROJECT_NAME%\assets"
xcopy "%TEMP_TEMPLATE_DIR%\assets" "%PROJECT_NAME%\assets" /E /I /Y
if errorlevel 1 exit /b 1

echo.
echo Copying analysis_options.yaml...
if exist "%TEMP_TEMPLATE_DIR%\analysis_options.yaml" (
  copy /Y "%TEMP_TEMPLATE_DIR%\analysis_options.yaml" "%PROJECT_NAME%\analysis_options.yaml"
)

echo.
echo Replacing pubspec dependencies section from template...

powershell -NoProfile -ExecutionPolicy Bypass -Command "$projectName='%PROJECT_NAME%'; $projectPubspec='%PROJECT_NAME%\pubspec.yaml'; $templatePubspec='%TEMP_TEMPLATE_DIR%\pubspec.yaml'; $projectText=Get-Content -LiteralPath $projectPubspec -Raw; $templateText=Get-Content -LiteralPath $templatePubspec -Raw; $projectText=[regex]::Replace($projectText, '(?m)^name:\s*.*$', 'name: ' + $projectName, 1); $projectTop=[regex]::Replace($projectText, '(?ms)^dependencies:\s*.*$', '', 1).TrimEnd(); $templateFromDependencies=[regex]::Match($templateText, '(?ms)^dependencies:\s*.*$').Value.TrimEnd(); if([string]::IsNullOrWhiteSpace($templateFromDependencies)){ throw 'Template dependencies section not found'; }; $finalText=$projectTop + \"`r`n`r`n\" + $templateFromDependencies + \"`r`n\"; Set-Content -LiteralPath $projectPubspec -Value $finalText"
if errorlevel 1 exit /b 1

echo.
echo Replacing old package imports...

powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%PROJECT_NAME%\lib' -Recurse -File -Filter *.dart | ForEach-Object { $content = Get-Content -LiteralPath $_.FullName -Raw; $content = $content -replace 'package:relief_app/', 'package:%PROJECT_NAME%/'; Set-Content -LiteralPath $_.FullName -Value $content }"
if errorlevel 1 exit /b 1

echo.
echo Setting FVM version inside project...
cd %PROJECT_NAME%
call fvm use %FLUTTER_VERSION%
if errorlevel 1 exit /b 1

echo.
echo Running pub get...
call fvm flutter pub get
if errorlevel 1 exit /b 1

cd ..

echo.
echo Cleaning temp files...
if exist "%TEMP_TEMPLATE_DIR%" rmdir /s /q "%TEMP_TEMPLATE_DIR%"

echo.
echo Done!
echo Project created: %PROJECT_NAME%
echo Flutter version: %FLUTTER_VERSION%
echo Application ID should be: %ORG_NAME%.%PROJECT_NAME%
echo.