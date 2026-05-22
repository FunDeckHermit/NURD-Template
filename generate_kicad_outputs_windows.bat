@echo off
setlocal enabledelayedexpansion

REM ###############################################################################
REM KiCad Artifact Generation Script for Windows
REM Generates: Schematic PDF, PCB PDF, Renders, STEP, Drill, Gerbers, BOM, Placement
REM ###############################################################################

REM Get current timestamp
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c-%%a-%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a:%%b)
set RUN_DATETIME=%mydate% %mytime%

set START_TIME=%time%
set OUTPUT_DIR=%1
if "!OUTPUT_DIR!"=="" set OUTPUT_DIR=kicad-artifacts

set TEMP_DIR=%TEMP%\kicad-build-temp-%RANDOM%

echo Output directory: %OUTPUT_DIR%
echo Temporary directory: %TEMP_DIR%

REM ###############################################################################
REM Find KiCad installation
REM ###############################################################################

set KICAD_CLI=

if exist "C:\Program Files\KiCad\10.0\bin\kicad-cli.exe" (
    set "KICAD_CLI=C:\Program Files\KiCad\10.0\bin\kicad-cli.exe"
    echo Found KiCad 10.0
) else if exist "C:\Program Files\KiCad\9.0\bin\kicad-cli.exe" (
    set "KICAD_CLI=C:\Program Files\KiCad\9.0\bin\kicad-cli.exe"
    echo Found KiCad 9.0
) else if exist "C:\Program Files\KiCad\8.0\bin\kicad-cli.exe" (
    set "KICAD_CLI=C:\Program Files\KiCad\8.0\bin\kicad-cli.exe"
    echo Found KiCad 8.0
) else if exist "C:\Program Files (x86)\KiCad\10.0\bin\kicad-cli.exe" (
    set "KICAD_CLI=C:\Program Files (x86)\KiCad\10.0\bin\kicad-cli.exe"
    echo Found KiCad 10.0 x86
) else if exist "C:\Program Files (x86)\KiCad\9.0\bin\kicad-cli.exe" (
    set "KICAD_CLI=C:\Program Files (x86)\KiCad\9.0\bin\kicad-cli.exe"
    echo Found KiCad 9.0 x86
) else if exist "C:\Program Files (x86)\KiCad\8.0\bin\kicad-cli.exe" (
    set "KICAD_CLI=C:\Program Files (x86)\KiCad\8.0\bin\kicad-cli.exe"
    echo Found KiCad 8.0 x86
)

if "!KICAD_CLI!"=="" (
    echo ERROR: kicad-cli not found
    exit /b 1
)

echo Using: !KICAD_CLI!

REM ###############################################################################
REM Locate project files
REM ###############################################################################

set PROJ_FILE=
for %%f in (*.kicad_pro) do (
    set PROJ_FILE=%%f
    goto found_proj
)

:found_proj
if "!PROJ_FILE!"=="" (
    echo ERROR: No kicad_pro file found
    exit /b 1
)

REM Extract base name without extension
for %%f in ("!PROJ_FILE!") do set BASE=%%~nf
set BASE=%BASE:.kicad_pro=%

set SCHEMATIC=%BASE%.kicad_sch
set PCB=%BASE%.kicad_pcb
set PROJECT_NAME=%BASE%

if not exist "!SCHEMATIC!" (
    echo ERROR: Missing schematic file
    exit /b 1
)

if not exist "!PCB!" (
    echo ERROR: Missing PCB file
    exit /b 1
)

echo Project name: %PROJECT_NAME%
echo Schematic:    %SCHEMATIC%
echo PCB:          %PCB%

REM ###############################################################################
REM Prepare temporary folders
REM ###############################################################################

mkdir "%TEMP_DIR%\gerbers" 2>nul
mkdir "%TEMP_DIR%\drill" 2>nul
set REPORT_FILE=%TEMP_DIR%\report.txt
set LOG_FILE=%TEMP_DIR%\build.log

REM ###############################################################################
REM Detect PCB layers
REM ###############################################################################

set GERBER_LAYERS=F.Cu,B.Cu,F.Mask,B.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts

findstr /m "In1.Cu" "!PCB!" >nul 2>&1
if not errorlevel 1 (
    set GERBER_LAYERS=F.Cu,In1.Cu,In2.Cu,B.Cu,F.Mask,B.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts
)

findstr /m "In3.Cu" "!PCB!" >nul 2>&1
if not errorlevel 1 (
    set GERBER_LAYERS=F.Cu,In1.Cu,In2.Cu,In3.Cu,B.Cu,F.Mask,B.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts
)

echo Detected gerber layers: %GERBER_LAYERS%

set RENDER_WIDTH=1400
set RENDER_HEIGHT=1400
set RENDER_QUALITY=high
set ISO_ROTATION=315,0,45

REM ###############################################################################
REM Schematic PDF
REM ###############################################################################

echo.
echo Exporting schematic PDF...
"!KICAD_CLI!" sch export pdf "!SCHEMATIC!" --output "%TEMP_DIR%\%PROJECT_NAME%_schematic.pdf"
if errorlevel 1 (
    echo ERROR: Exporting schematic PDF failed
    rmdir /s /q "%TEMP_DIR%" >nul 2>&1
    exit /b 1
)

REM ###############################################################################
REM PCB PDF
REM ###############################################################################

echo Exporting PCB PDF...
"!KICAD_CLI!" pcb export pdf "!PCB!" --layers F.Cu,B.Cu --output "%TEMP_DIR%\%PROJECT_NAME%_pcb.pdf"
if errorlevel 1 (
    echo ERROR: Exporting PCB PDF failed
    rmdir /s /q "%TEMP_DIR%" >nul 2>&1
    exit /b 1
)

REM ###############################################################################
REM Top render
REM ###############################################################################

echo Exporting top render...
"!KICAD_CLI!" pcb render "!PCB!" --side top --quality %RENDER_QUALITY% --width %RENDER_WIDTH% --height %RENDER_HEIGHT% --output "%TEMP_DIR%\%PROJECT_NAME%_render-top.png"
if errorlevel 1 (
    echo ERROR: Exporting top render failed
    rmdir /s /q "%TEMP_DIR%" >nul 2>&1
    exit /b 1
)

REM ###############################################################################
REM Bottom render
REM ###############################################################################

echo Exporting bottom render...
"!KICAD_CLI!" pcb render "!PCB!" --side bottom --quality %RENDER_QUALITY% --width %RENDER_WIDTH% --height %RENDER_HEIGHT% --output "%TEMP_DIR%\%PROJECT_NAME%_render-bottom.png"
if errorlevel 1 (
    echo ERROR: Exporting bottom render failed
    rmdir /s /q "%TEMP_DIR%" >nul 2>&1
    exit /b 1
)

REM ###############################################################################
REM Isometric render
REM ###############################################################################

echo Exporting isometric render...
"!KICAD_CLI!" pcb render "!PCB!" --side top --quality %RENDER_QUALITY% --width %RENDER_WIDTH% --height %RENDER_HEIGHT% --rotate %ISO_ROTATION% --output "%TEMP_DIR%\%PROJECT_NAME%_render-iso.png"
if errorlevel 1 (
    echo ERROR: Exporting isometric render failed
    rmdir /s /q "%TEMP_DIR%" >nul 2>&1
    exit /b 1
)

REM ###############################################################################
REM Drill files with map
REM ###############################################################################

echo Exporting drill files...
"!KICAD_CLI!" pcb export drill "!PCB!" --output "%TEMP_DIR%\drill" --format excellon --drill-origin absolute --generate-map --map-format pdf
if errorlevel 1 (
    echo ERROR: Exporting drill files failed
    rmdir /s /q "%TEMP_DIR%" >nul 2>&1
    exit /b 1
)

timeout /t 1 /nobreak >nul

REM Rename drill map PDF
for %%f in ("%TEMP_DIR%\drill\*.pdf") do (
    if not "%%f"=="%TEMP_DIR%\drill\%PROJECT_NAME%_drill-map.pdf" (
        move /y "%%f" "%TEMP_DIR%\drill\%PROJECT_NAME%_drill-map.pdf" >nul 2>&1
    )
)

REM ###############################################################################
REM STEP model
REM ###############################################################################

echo Exporting STEP model...
"!KICAD_CLI!" pcb export step "!PCB!" --output "%TEMP_DIR%\%PROJECT_NAME%_board.step" --force
if errorlevel 1 (
    echo ERROR: Exporting STEP model failed
    rmdir /s /q "%TEMP_DIR%" >nul 2>&1
    exit /b 1
)

REM ###############################################################################
REM Placement CSV
REM ###############################################################################

echo Exporting Placement CSV...
"!KICAD_CLI!" pcb export pos "!PCB!" --output "%TEMP_DIR%\%PROJECT_NAME%_placement.csv" --side both --format csv --units mm --use-drill-file-origin --exclude-dnp
if errorlevel 1 (
    echo ERROR: Exporting Placement CSV failed
    rmdir /s /q "%TEMP_DIR%" >nul 2>&1
    exit /b 1
)

powershell -Command "((Get-Content '%TEMP_DIR%\%PROJECT_NAME%_placement.csv' -Raw) -replace 'Ref,Val,Package,PosX,PosY,Rot,Side', 'Designator,Val,Package,Mid X,Mid Y,Rotation,Layer') | Set-Content '%TEMP_DIR%\%PROJECT_NAME%_placement.csv'" >nul 2>&1

REM ###############################################################################
REM BOM CSV
REM ###############################################################################

echo Exporting BOM CSV...
"!KICAD_CLI!" sch export bom "!SCHEMATIC!" --fields "Reference,Value,MPN,Footprint,^${QUANTITY}" --labels "Designator,Comment,MPN,Footprint,Quantity" --exclude-dnp --group-by "Value" --ref-range-delimiter "" --output "%TEMP_DIR%\%PROJECT_NAME%_bom.csv"
if errorlevel 1 (
    echo ERROR: Exporting BOM CSV failed
    rmdir /s /q "%TEMP_DIR%" >nul 2>&1
    exit /b 1
)

powershell -Command "^
$csv = Import-Csv '%TEMP_DIR%\%PROJECT_NAME%_bom.csv'; ^
foreach ($row in $csv) { ^
    $refs = $row.Designator -split ','; ^
    $chunk = ''; ^
    $output = @(); ^
    foreach ($ref in $refs) { ^
        $ref = $ref.Trim(); ^
        $test = if ($chunk -eq '') { $ref } else { $chunk + ',' + $ref }; ^
        if ((\"\"\"\" + $test + \"\"\"\").Length -gt 2048) { ^
            $output += '\"' + $chunk + '\"'; ^
            $chunk = $ref; ^
        } else { ^
            $chunk = $test; ^
        } ^
    } ^
    if ($chunk -ne '') { ^
        $output += '\"' + $chunk + '\"'; ^
    } ^
    $row.Designator = $output -join ',' ^
} ^
$csv | Export-Csv -Path '%TEMP_DIR%\%PROJECT_NAME%_bom.csv' -NoTypeInformation ^
" >nul 2>&1

REM ###############################################################################
REM Gerbers
REM ###############################################################################

echo Exporting Gerbers...
"!KICAD_CLI!" pcb export gerbers "!PCB!" --output "%TEMP_DIR%\gerbers" --layers "%GERBER_LAYERS%"
if errorlevel 1 (
    echo ERROR: Exporting Gerbers failed
    rmdir /s /q "%TEMP_DIR%" >nul 2>&1
    exit /b 1
)

timeout /t 1 /nobreak >nul

echo Exporting drill files for Gerber package...
"!KICAD_CLI!" pcb export drill "!PCB!" --output "%TEMP_DIR%\gerbers" --format excellon --drill-origin absolute --excellon-zeros-format decimal --excellon-units mm --excellon-oval-format route
if errorlevel 1 (
    echo ERROR: Exporting Drill Files failed
    rmdir /s /q "%TEMP_DIR%" >nul 2>&1
    exit /b 1
)

del /q "%TEMP_DIR%\gerbers\*.gbrjob" >nul 2>&1

echo Creating Gerbers ZIP...
cd "%TEMP_DIR%\gerbers"
powershell -Command "Compress-Archive -Path * -DestinationPath '..\%PROJECT_NAME%_gerbers.zip' -Force" >nul 2>&1
cd "%~dp0"

if not exist "%TEMP_DIR%\%PROJECT_NAME%_gerbers.zip" (
    echo ERROR: Failed to create gerbers ZIP
    rmdir /s /q "%TEMP_DIR%" >nul 2>&1
    exit /b 1
)

rmdir /s /q "%TEMP_DIR%\gerbers" >nul 2>&1

REM ###############################################################################
REM Report
REM ###############################################################################

echo Writing report.txt...

(
echo KiCad Export Report
echo ===================
echo.
echo Project: %PROJECT_NAME%
echo Run at: %RUN_DATETIME%
echo.
echo Render settings:
echo   Quality: %RENDER_QUALITY%
echo   Resolution: %RENDER_WIDTH%x%RENDER_HEIGHT%
echo   Isometric rotation: %ISO_ROTATION%
echo.
echo Gerber layers:
echo   %GERBER_LAYERS%
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
) > "%REPORT_FILE%"

dir /b "%TEMP_DIR%" >> "%REPORT_FILE%" 2>&1

REM ###############################################################################
REM Move files to final output directory
REM ###############################################################################

echo Moving files to final output directory...
mkdir "%OUTPUT_DIR%" >nul 2>&1
move /y "%TEMP_DIR%\*" "%OUTPUT_DIR%" >nul 2>&1

REM ###############################################################################
REM Cleanup and Done
REM ###############################################################################

rmdir /s /q "%TEMP_DIR%" >nul 2>&1

echo.
echo All artifacts generated in: %OUTPUT_DIR%
echo.
dir /b "%OUTPUT_DIR%"

endlocal
