@echo off
setlocal enabledelayedexpansion

REM ###############################################################################
REM KiCad Production Export Script (Stable / No Python / No fragile PowerShell)
REM Outputs: Gerbers ZIP + BOM CSV + Placement CSV + Report
REM ###############################################################################

REM ------------------------------------------------------------------------------
REM Check PowerShell (only for ZIP + timestamp)
REM ------------------------------------------------------------------------------

where powershell >nul 2>&1
if errorlevel 1 (
    echo ERROR: PowerShell not found
    exit /b 1
)

REM ------------------------------------------------------------------------------
REM Timestamp (safe single-line PS)
REM ------------------------------------------------------------------------------

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm"') do (
    set RUN_DATETIME=%%i
)

REM ------------------------------------------------------------------------------
REM Output paths
REM ------------------------------------------------------------------------------

set OUTPUT_DIR=%1
if "!OUTPUT_DIR!"=="" set OUTPUT_DIR=kicad-artifacts

set TEMP_DIR=%TEMP%\kicad-build-%RANDOM%

mkdir "%TEMP_DIR%" >nul 2>&1
mkdir "%TEMP_DIR%\gerbers" >nul 2>&1

echo Output: %OUTPUT_DIR%
echo Temp:   %TEMP_DIR%

REM ------------------------------------------------------------------------------
REM Find KiCad CLI
REM ------------------------------------------------------------------------------

set KICAD_CLI=

for /f "delims=" %%i in ('where kicad-cli.exe 2^>nul') do (
    set "KICAD_CLI=%%i"
    goto kicad_found
)

for %%v in (12.0 11.0 10.0 9.0 8.0) do (
    if exist "C:\Program Files\KiCad\%%v\bin\kicad-cli.exe" (
        set "KICAD_CLI=C:\Program Files\KiCad\%%v\bin\kicad-cli.exe"
        goto kicad_found
    )
    if exist "C:\Program Files (x86)\KiCad\%%v\bin\kicad-cli.exe" (
        set "KICAD_CLI=C:\Program Files (x86)\KiCad\%%v\bin\kicad-cli.exe"
        goto kicad_found
    )
)

:kicad_found

if "!KICAD_CLI!"=="" (
    echo ERROR: KiCad CLI not found
    exit /b 1
)

echo Using: !KICAD_CLI!

REM ------------------------------------------------------------------------------
REM Find project
REM ------------------------------------------------------------------------------

set PROJ_FILE=

for %%f in (*.kicad_pro) do (
    set PROJ_FILE=%%f
    goto proj_found
)

:proj_found

if "!PROJ_FILE!"=="" (
    echo ERROR: No .kicad_pro found
    exit /b 1
)

for %%f in ("!PROJ_FILE!") do set BASE=%%~nf

set PCB=%BASE%.kicad_pcb
set SCH=%BASE%.kicad_sch

if not exist "!PCB!" (
    echo ERROR: Missing PCB file
    exit /b 1
)

if not exist "!SCH!" (
    echo ERROR: Missing schematic file
    exit /b 1
)

echo Project: %BASE%

REM ------------------------------------------------------------------------------
REM Layer set (safe default)
REM ------------------------------------------------------------------------------

set LAYERS=F.Cu,B.Cu,F.Mask,B.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts

REM ------------------------------------------------------------------------------
REM GERBERS
REM ------------------------------------------------------------------------------

echo.
echo Exporting Gerbers...

"!KICAD_CLI!" pcb export gerbers "!PCB!" ^
    --output "%TEMP_DIR%\gerbers" ^
    --layers "%LAYERS%"

if errorlevel 1 (
    echo ERROR: Gerber export failed
    rmdir /s /q "%TEMP_DIR%" >nul 2>&1
    exit /b 1
)

echo Exporting drills...

"!KICAD_CLI!" pcb export drill "!PCB!" ^
    --output "%TEMP_DIR%\gerbers" ^
    --format excellon

if errorlevel 1 (
    echo ERROR: Drill export failed
    rmdir /s /q "%TEMP_DIR%" >nul 2>&1
    exit /b 1
)

REM ------------------------------------------------------------------------------
REM ZIP (robust single-line PowerShell)
REM ------------------------------------------------------------------------------

echo Creating ZIP...

powershell -NoProfile -Command "Compress-Archive -Path '%TEMP_DIR%\gerbers\*' -DestinationPath '%TEMP_DIR%\%BASE%_gerbers.zip' -Force"

if not exist "%TEMP_DIR%\%BASE%_gerbers.zip" (
    echo ERROR: ZIP failed
    rmdir /s /q "%TEMP_DIR%" >nul 2>&1
    exit /b 1
)

REM ------------------------------------------------------------------------------
REM Placement CSV (NO post-processing)
REM ------------------------------------------------------------------------------

echo Exporting placement...

"!KICAD_CLI!" pcb export pos "!PCB!" ^
    --output "%TEMP_DIR%\placement.csv" ^
    --format csv ^
    --units mm ^
    --side both ^
    --exclude-dnp

if errorlevel 1 (
    echo ERROR: Placement export failed
    rmdir /s /q "%TEMP_DIR%" >nul 2>&1
    exit /b 1
)

REM ------------------------------------------------------------------------------
REM BOM CSV (NO post-processing)
REM ------------------------------------------------------------------------------

echo Exporting BOM...

"!KICAD_CLI!" sch export bom "!SCH!" ^
    --fields "Reference,Value,MPN,Footprint,^${QUANTITY}" ^
    --labels "Designator,Value,MPN,Footprint,Qty" ^
    --group-by "Value" ^
    --output "%TEMP_DIR%\bom.csv"

if errorlevel 1 (
    echo ERROR: BOM export failed
    rmdir /s /q "%TEMP_DIR%" >nul 2>&1
    exit /b 1
)

REM ------------------------------------------------------------------------------
REM Report
REM ------------------------------------------------------------------------------

(
echo KiCad Export Report
echo ====================
echo Project: %BASE%
echo Date: %RUN_DATETIME%
echo.
echo Files:
echo - %BASE%_gerbers.zip
echo - bom.csv
echo - placement.csv
echo.
echo Layers:
echo %LAYERS%
) > "%TEMP_DIR%\report.txt"

REM ------------------------------------------------------------------------------
REM Move output
REM ------------------------------------------------------------------------------

mkdir "%OUTPUT_DIR%" >nul 2>&1

copy "%TEMP_DIR%\%BASE%_gerbers.zip" "%OUTPUT_DIR%\" >nul
copy "%TEMP_DIR%\bom.csv" "%OUTPUT_DIR%\" >nul
copy "%TEMP_DIR%\placement.csv" "%OUTPUT_DIR%\" >nul
copy "%TEMP_DIR%\report.txt" "%OUTPUT_DIR%\" >nul

REM ------------------------------------------------------------------------------
REM Cleanup
REM ------------------------------------------------------------------------------

rmdir /s /q "%TEMP_DIR%" >nul 2>&1

echo.
echo DONE
dir /b "%OUTPUT_DIR%"

endlocal
