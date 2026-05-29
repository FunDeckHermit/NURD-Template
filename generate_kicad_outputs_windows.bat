@echo off
setlocal enabledelayedexpansion

REM ###############################################################################
REM KiCad Production Export Script (STABLE HEADERS / NO DATA LOSS / DYNAMIC LAYERS)
REM ###############################################################################

REM ------------------------------------------------------------------------------
REM Timestamp (safe single-line PS)
REM ------------------------------------------------------------------------------

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do (
    set RUN_DATETIME=%%i
)

for /f %%i in ('powershell -NoProfile -Command "[int](Get-Date -UFormat %%s)"') do (
    set START_TIME=%%i
)

REM ------------------------------------------------------------------------------
REM Setup
REM ------------------------------------------------------------------------------

set OUTPUT_DIR=%1
if "!OUTPUT_DIR!"=="" set OUTPUT_DIR=kicad-artifacts

set TEMP_DIR=%TEMP%\kicad-build-%RANDOM%

mkdir "%TEMP_DIR%" >nul 2>&1
mkdir "%TEMP_DIR%\gerbers" >nul 2>&1
mkdir "%TEMP_DIR%\drill" >nul 2>&1

echo Output: %OUTPUT_DIR%
echo Temp:   %TEMP_DIR%

REM Clean output directory if it exists
if exist "%OUTPUT_DIR%" (
    echo Cleaning existing output directory: %OUTPUT_DIR%
    rmdir /s /q "%OUTPUT_DIR%" >nul 2>&1
)

REM Setup logging
set LOG_FILE=%TEMP_DIR%\build.log

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

REM Render settings
set RENDER_WIDTH=1400
set RENDER_HEIGHT=1400
set RENDER_QUALITY=high
set ISO_ROTATION=315,0,45

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
    set LAYERS=F.Cu,In1.Cu,In2.Cu,In3.Cu,B.Cu,B.Mask,F.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts
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
REM SCHEMATIC PDF
REM ------------------------------------------------------------------------------

echo.
echo Exporting schematic PDF...

"!KICAD_CLI!" sch export pdf "!SCH!" ^
    --output "%TEMP_DIR%\!BASE!_schematic.pdf"

if !errorlevel! neq 0 (
    echo ERROR: Exporting schematic PDF failed!
    exit /b 1
)

REM Wait for file
timeout /t 2 /nobreak >nul 2>&1

REM ------------------------------------------------------------------------------
REM PCB PDF
REM ------------------------------------------------------------------------------

echo Exporting PCB PDF...

"!KICAD_CLI!" pcb export pdf "!PCB!" ^
    --layers F.Cu,B.Cu ^
    --output "%TEMP_DIR%\!BASE!_pcb.pdf"

if !errorlevel! neq 0 (
    echo ERROR: Exporting PCB PDF failed!
    exit /b 1
)

timeout /t 2 /nobreak >nul 2>&1

REM ------------------------------------------------------------------------------
REM PCB RENDERS
REM ------------------------------------------------------------------------------

echo Exporting top render...

"!KICAD_CLI!" pcb render "!PCB!" ^
    --side top ^
    --quality %RENDER_QUALITY% ^
    --width %RENDER_WIDTH% ^
    --height %RENDER_HEIGHT% ^
    --output "%TEMP_DIR%\!BASE!_render-top.png"

if !errorlevel! neq 0 (
    echo ERROR: Exporting top render failed!
    exit /b 1
)

timeout /t 2 /nobreak >nul 2>&1

echo Exporting bottom render...

"!KICAD_CLI!" pcb render "!PCB!" ^
    --side bottom ^
    --quality %RENDER_QUALITY% ^
    --width %RENDER_WIDTH% ^
    --height %RENDER_HEIGHT% ^
    --output "%TEMP_DIR%\!BASE!_render-bottom.png"

if !errorlevel! neq 0 (
    echo ERROR: Exporting bottom render failed!
    exit /b 1
)

timeout /t 2 /nobreak >nul 2>&1

echo Exporting isometric render...

"!KICAD_CLI!" pcb render "!PCB!" ^
    --side top ^
    --quality %RENDER_QUALITY% ^
    --width %RENDER_WIDTH% ^
    --height %RENDER_HEIGHT% ^
    --rotate %ISO_ROTATION% ^
    --output "%TEMP_DIR%\!BASE!_render-iso.png"

if !errorlevel! neq 0 (
    echo ERROR: Exporting isometric render failed!
    exit /b 1
)

timeout /t 2 /nobreak >nul 2>&1

REM ------------------------------------------------------------------------------
REM DRILL FILES + MAP
REM ------------------------------------------------------------------------------

echo Exporting drill files...

"!KICAD_CLI!" pcb export drill "!PCB!" ^
    --output "%TEMP_DIR%\drill" ^
    --format excellon ^
    --drill-origin absolute ^
    --generate-map ^
    --map-format pdf

if !errorlevel! neq 0 (
    echo ERROR: Exporting drill files failed!
    exit /b 1
)

timeout /t 2 /nobreak >nul 2>&1

REM Rename drill map if present
for %%f in ("%TEMP_DIR%\drill\*.pdf") do (
    if not "%%~nf"=="!BASE!_drill-map.pdf" (
        ren "%%f" "!BASE!_drill-map.pdf"
    )
)

REM Move drill files to temp root
move "%TEMP_DIR%\drill\*" "%TEMP_DIR%\" >nul 2>&1
rmdir "%TEMP_DIR%\drill" >nul 2>&1

REM ------------------------------------------------------------------------------
REM STEP MODEL
REM ------------------------------------------------------------------------------

echo Exporting STEP model...

"!KICAD_CLI!" pcb export step "!PCB!" ^
    --output "%TEMP_DIR%\!BASE!_board.step" ^
    --force

if !errorlevel! neq 0 (
    echo ERROR: Exporting STEP model failed!
    exit /b 1
)

timeout /t 2 /nobreak >nul 2>&1

REM ------------------------------------------------------------------------------
REM PLACEMENT
REM ------------------------------------------------------------------------------

echo Exporting placement CSV...

"!KICAD_CLI!" pcb export pos "!PCB!" ^
    --output "%TEMP_DIR%\!BASE!_placement_raw.csv" ^
    --format csv ^
    --units mm ^
    --side both ^
    --exclude-dnp

if !errorlevel! neq 0 (
    echo ERROR: Exporting placement CSV failed!
    exit /b 1
)

timeout /t 2 /nobreak >nul 2>&1

REM Fix header line
powershell -NoProfile -Command "& {$content = Get-Content '%TEMP_DIR%\!BASE!_placement_raw.csv'; $content[0] = 'Designator,Val,Package,\"Mid X\",\"Mid Y\",Rotation,Layer'; Set-Content '%TEMP_DIR%\!BASE!_placement.csv' $content}"

del "%TEMP_DIR%\!BASE!_placement_raw.csv" >nul 2>&1

REM ------------------------------------------------------------------------------
REM BOM (RAW - NO LOSS, NO RANGE PROBLEMS)
REM ------------------------------------------------------------------------------

echo Exporting BOM...

"!KICAD_CLI!" sch export bom "!SCH!" ^
    --fields "Reference,Value,MPN,Footprint,^${QUANTITY}" ^
    --labels "Designator,Value,MPN,Footprint,Qty" ^
    --output "%TEMP_DIR%\bom_raw.csv"

timeout /t 2 /nobreak >nul 2>&1

REM ------------------------------------------------------------------------------
REM BOM DEDUPLICATION (AGGREGATE DUPLICATES BY MPN)
REM ------------------------------------------------------------------------------

echo Deduplicating BOM by MPN...

powershell -NoProfile -Command "& {$csv = Import-Csv '%TEMP_DIR%\bom_raw.csv'; $grouped = @{}; foreach ($row in $csv) { $mpn = $row.MPN.Trim(); if ([string]::IsNullOrWhiteSpace($mpn)) { $mpn = 'NO_MPN' }; if (-not $grouped.ContainsKey($mpn)) { $grouped[$mpn] = [PSCustomObject]@{ Designator = @($row.Designator); Value = $row.Value; MPN = $mpn; Footprint = $row.Footprint; Qty = [int]$row.Qty } } else { $grouped[$mpn].Designator += $row.Designator; $grouped[$mpn].Qty += [int]$row.Qty } }; $output = @(); foreach ($key in ($grouped.Keys | Sort-Object)) { $designators = $grouped[$key].Designator -join ' '; $output += [PSCustomObject]@{ Designator = $designators; Value = $grouped[$key].Value; MPN = $grouped[$key].MPN; Footprint = $grouped[$key].Footprint; Qty = $grouped[$key].Qty } }; $output | Export-Csv -Path '%TEMP_DIR%\!BASE!_bom.csv' -NoTypeInformation -Encoding UTF8 }"

REM Fix 2048-char limit for JLCPCB compatibility
powershell -NoProfile -Command "& {$csv = Import-Csv '%TEMP_DIR%\!BASE!_bom.csv'; $output = @(); foreach ($row in $csv) { $desigs = $row.Designator -split ' '; $chunk = ''; foreach ($d in $desigs) { $test = if ($chunk) { $chunk + ',' + $d } else { $d }; if (($test.Length + 2) -gt 2048) { $output += [PSCustomObject]@{ Designator = $chunk; Value = $row.Value; MPN = $row.MPN; Footprint = $row.Footprint; Qty = $row.Qty }; $chunk = $d } else { $chunk = $test } }; if ($chunk) { $output += [PSCustomObject]@{ Designator = $chunk; Value = $row.Value; MPN = $row.MPN; Footprint = $row.Footprint; Qty = $row.Qty } } }; $output | Export-Csv -Path '%TEMP_DIR%\!BASE!_bom.csv' -NoTypeInformation -Encoding UTF8 }"

del "%TEMP_DIR%\bom_raw.csv" >nul 2>&1

REM ------------------------------------------------------------------------------
REM GERBERS
REM ------------------------------------------------------------------------------

echo Exporting Gerbers...

"!KICAD_CLI!" pcb export gerbers "!PCB!" ^
    --output "%TEMP_DIR%\gerbers" ^
    --layers "!LAYERS!"

if !errorlevel! neq 0 (
    echo ERROR: Exporting gerbers failed!
    exit /b 1
)

timeout /t 2 /nobreak >nul 2>&1

echo Exporting Drill Files ^(JLCPCB-compatible Excellon^)...

"!KICAD_CLI!" pcb export drill "!PCB!" ^
    --output "%TEMP_DIR%\gerbers" ^
    --format excellon ^
    --drill-origin absolute ^
    --excellon-zeros-format decimal ^
    --excellon-units mm ^
    --excellon-oval-format route

if !errorlevel! neq 0 (
    echo ERROR: Exporting Drill Files failed!
    exit /b 1
)

timeout /t 2 /nobreak >nul 2>&1

REM Remove job files
del /q "%TEMP_DIR%\gerbers\*.gbrjob" >nul 2>&1

REM Zip gerbers - using pushd to ensure we're in the right directory
echo Zipping Gerbers and Drill Files...

pushd "%TEMP_DIR%\gerbers"
for /f %%f in ('dir /b *.* 2^>nul ^| find /c /v ""') do set GERBER_COUNT=%%f
popd

if !GERBER_COUNT! gtr 0 (
    cd /d "%TEMP_DIR%\gerbers"
    powershell -NoProfile -Command "& {Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::CreateFromDirectory('.', '%TEMP_DIR%\!BASE!_gerbers.zip')}" >nul 2>&1
    cd /d "%TEMP_DIR%"
    rmdir /s /q "%TEMP_DIR%\gerbers" >nul 2>&1
) else (
    echo WARNING: No gerber files created
    rmdir /s /q "%TEMP_DIR%\gerbers" >nul 2>&1
)

REM ------------------------------------------------------------------------------
REM REPORT
REM ------------------------------------------------------------------------------

for /f %%i in ('powershell -NoProfile -Command "[int](Get-Date -UFormat %%s)"') do (
    set END_TIME=%%i
)

set /a DURATION=%END_TIME% - %START_TIME%

echo Writing report.txt

(
    echo KiCad Export Report
    echo ===================
    echo.
    echo Project: !BASE!
    echo Run at: %RUN_DATETIME%
    echo Duration: %DURATION%s
    echo.
    echo Render settings:
    echo   Quality: %RENDER_QUALITY%
    echo   Resolution: %RENDER_WIDTH%x%RENDER_HEIGHT%
    echo   Isometric rotation: %ISO_ROTATION%
    echo.
    echo Gerber layers:
    echo   !LAYERS!
    echo.
    echo Drill:
    echo   Format: Excellon
    echo   Map: PDF
    echo.
    echo Placement:
    echo   Format: CSV
    echo   Units: mm
    echo   Side: both
    echo.
    echo Generated files:
) > "%TEMP_DIR%\report.txt"

for /f "delims=" %%f in ('dir /b "%TEMP_DIR%"') do (
    echo   %%f >> "%TEMP_DIR%\report.txt"
)

REM ------------------------------------------------------------------------------
REM OUTPUT
REM ------------------------------------------------------------------------------

mkdir "%OUTPUT_DIR%" >nul 2>&1

for /f "delims=" %%f in ('dir /b "%TEMP_DIR%"') do (
    move "%TEMP_DIR%\%%f" "%OUTPUT_DIR%\" >nul 2>&1
)

rmdir /s /q "%TEMP_DIR%" >nul 2>&1

echo.
echo DONE
dir /s "%OUTPUT_DIR%"

endlocal
