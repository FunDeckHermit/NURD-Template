@echo off
setlocal enabledelayedexpansion

REM ###############################################################################
REM KiCad Production Export Script (STABLE HEADERS / NO DATA LOSS / DYNAMIC LAYERS)
REM ###############################################################################

REM ------------------------------------------------------------------------------
REM Timestamp (safe single-line PS)
REM ------------------------------------------------------------------------------

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm"') do (
    set RUN_DATETIME=%%i
)

REM ------------------------------------------------------------------------------
REM Setup
REM ------------------------------------------------------------------------------

set OUTPUT_DIR=%1
if "!OUTPUT_DIR!"=="" set OUTPUT_DIR=kicad-artifacts

set TEMP_DIR=%TEMP%\kicad-build-%RANDOM%

mkdir "%TEMP_DIR%" >nul 2>&1
mkdir "%TEMP_DIR%\gerbers" >nul 2>&1

echo Output: %OUTPUT_DIR%
echo Temp:   %TEMP_DIR%

REM ------------------------------------------------------------------------------
REM KiCad CLI
REM ------------------------------------------------------------------------------

set KICAD_CLI=

for /f "delims=" %%i in ('where kicad-cli.exe 2^>nul') do (
    set "KICAD_CLI=%%i"
    goto found
)

for %%v in (12.0 11.0 10.0 9.0 8.0) do (
    if exist "C:\Program Files\KiCad\%%v\bin\kicad-cli.exe" (
        set "KICAD_CLI=C:\Program Files\KiCad\%%v\bin\kicad-cli.exe"
        goto found
    )
)

:found

if "!KICAD_CLI!"=="" exit /b 1

echo Using: !KICAD_CLI!

REM ------------------------------------------------------------------------------
REM Project
REM ------------------------------------------------------------------------------

for %%f in (*.kicad_pro) do set PROJ=%%f
for %%f in ("!PROJ!") do set BASE=%%~nf

set PCB=%BASE%.kicad_pcb
set SCH=%BASE%.kicad_sch

echo Project: %BASE%

REM ------------------------------------------------------------------------------
REM DETECT LAYERS DYNAMICALLY
REM ------------------------------------------------------------------------------

echo Detecting layer count...

REM Export layer list to temp file
"!KICAD_CLI!" pcb layers "!PCB!" > "%TEMP_DIR%\layers_raw.txt" 2>&1

REM Build dynamic layer list from the PCB file
setlocal enabledelayedexpansion
set LAYERS=
set LAYER_COUNT=0

REM Parse KiCad PCB file for layer definitions
for /f "tokens=*" %%L in ('findstr /r "^  \(layer " "!PCB!"') do (
    set "LINE=%%L"
    REM Extract layer names (they come in format: (layer ID "LayerName"))
    if not "!LINE!"=="" (
        REM Count inner layers (In1.Cu, In2.Cu, etc)
        echo !LINE! | findstr /i "\.Cu" >nul
        if !errorlevel! equ 0 (
            set /a LAYER_COUNT+=1
        )
    )
)

REM Standard approach: query available copper layers
REM For most boards, use this comprehensive dynamic list that adapts
REM We'll use KiCad's export command without --layers to get all available layers

set LAYERS=F.Cu,B.Cu,B.Mask,F.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts

REM Check if it's a 4-layer board (In1.Cu, In2.Cu)
findstr /i "In1\.Cu" "!PCB!" >nul
if !errorlevel! equ 0 (
    set LAYERS=F.Cu,In1.Cu,In2.Cu,B.Cu,B.Mask,F.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts
    echo Detected 4-layer board
)

REM Check if it's a 6-layer board (In1.Cu, In2.Cu, In3.Cu, In4.Cu)
findstr /i "In3\.Cu" "!PCB!" >nul
if !errorlevel! equ 0 (
    set LAYERS=F.Cu,In1.Cu,In2.Cu,In3.Cu,In4.Cu,B.Cu,B.Mask,F.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts
    echo Detected 6-layer board
)

REM Check if it's an 8-layer board (In1-In6.Cu)
findstr /i "In5\.Cu" "!PCB!" >nul
if !errorlevel! equ 0 (
    set LAYERS=F.Cu,In1.Cu,In2.Cu,In3.Cu,In4.Cu,In5.Cu,In6.Cu,B.Cu,B.Mask,F.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts
    echo Detected 8-layer board
)

REM Check if it's a 10-layer board (In1-In8.Cu)
findstr /i "In7\.Cu" "!PCB!" >nul
if !errorlevel! equ 0 (
    set LAYERS=F.Cu,In1.Cu,In2.Cu,In3.Cu,In4.Cu,In5.Cu,In6.Cu,In7.Cu,In8.Cu,B.Cu,B.Mask,F.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts
    echo Detected 10-layer board
)

echo Using layers: !LAYERS!

endlocal & set LAYERS=%LAYERS%

REM ------------------------------------------------------------------------------
REM GERBERS
REM ------------------------------------------------------------------------------

"!KICAD_CLI!" pcb export gerbers "!PCB!" ^
    --output "%TEMP_DIR%\gerbers" ^
    --layers "%LAYERS%"

"!KICAD_CLI!" pcb export drill "!PCB!" ^
    --output "%TEMP_DIR%\gerbers" ^
    --format excellon

powershell -NoProfile -Command "Compress-Archive -Path '%TEMP_DIR%\gerbers\*' -DestinationPath '%TEMP_DIR%\%BASE%_gerbers.zip' -Force"

REM ------------------------------------------------------------------------------
REM PLACEMENT (FIXED HEADER ONLY)
REM ------------------------------------------------------------------------------

echo Exporting placement...

"!KICAD_CLI!" pcb export pos "!PCB!" ^
    --output "%TEMP_DIR%\placement_raw.csv" ^
    --format csv ^
    --units mm ^
    --side both ^
    --exclude-dnp

REM overwrite header ONLY (safe, deterministic)
(
set /p=Designator,Val,Package,Mid X,Mid Y,Rotation,Layer<nul
echo.
for /f "skip=1 delims=" %%A in (%TEMP_DIR%\placement_raw.csv) do echo %%A
) > "%TEMP_DIR%\placement.csv"

REM ------------------------------------------------------------------------------
REM BOM (RAW - NO LOSS, NO RANGE PROBLEMS)
REM ------------------------------------------------------------------------------

echo Exporting BOM...

"!KICAD_CLI!" sch export bom "!SCH!" ^
    --fields "Reference,Value,MPN,Footprint,^${QUANTITY}" ^
    --labels "Designator,Value,MPN,Footprint,Qty" ^
    --output "%TEMP_DIR%\bom.csv"

REM ------------------------------------------------------------------------------
REM REPORT
REM ------------------------------------------------------------------------------

(
echo KiCad Export Report
echo Project: %BASE%
echo Date: %RUN_DATETIME%
echo Layers: %LAYERS%
echo.
echo Files:
echo - %BASE%_gerbers.zip
echo - bom.csv
echo - placement.csv
) > "%TEMP_DIR%\report.txt"

REM ------------------------------------------------------------------------------
REM OUTPUT
REM ------------------------------------------------------------------------------

mkdir "%OUTPUT_DIR%" >nul 2>&1

copy "%TEMP_DIR%\%BASE%_gerbers.zip" "%OUTPUT_DIR%\" >nul
copy "%TEMP_DIR%\bom.csv" "%OUTPUT_DIR%\" >nul
copy "%TEMP_DIR%\placement.csv" "%OUTPUT_DIR%\" >nul
copy "%TEMP_DIR%\report.txt" "%OUTPUT_DIR%\" >nul

REM ------------------------------------------------------------------------------
REM CLEANUP
REM ------------------------------------------------------------------------------

rmdir /s /q "%TEMP_DIR%" >nul 2>&1

echo.
echo DONE
dir /b "%OUTPUT_DIR%"

endlocal
