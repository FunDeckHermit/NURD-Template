@echo off
setlocal enabledelayedexpansion

REM ###############################################################################
REM KiCad Artifact Generation Script for Windows
REM Generates: Gerbers (ZIP), BOM (CSV), Placement (CSV)
REM ###############################################################################

REM Get current timestamp
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c-%%a-%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a:%%b)
set RUN_DATETIME=%mydate% %mytime%

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
set REPORT_FILE=%TEMP_DIR%\report.txt

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

REM ###############################################################################
REM Gerbers
REM ###############################################################################

echo.
echo Exporting Gerbers...
"!KICAD_CLI!" pcb export gerbers "!PCB!" --output "%TEMP_DIR%\gerbers" --layers "%GERBER_LAYERS%"

if errorlevel 1 (
    echo ERROR: Exporting Gerbers failed
    rmdir /s /q "%TEMP_DIR%" >nul 2>&1
    exit /b 1
)

timeout /t 1 /nobreak >nul

REM ###############################################################################
REM Drill Files
REM ###############################################################################

echo Exporting Drill Files
"!KICAD_CLI!" pcb export drill "!PCB!" --output "%TEMP_DIR%\gerbers" --format excellon --drill-origin absolute --excellon-zeros-format decimal --excellon-units mm --excellon-oval-format route

if errorlevel 1 (
    echo ERROR: Exporting Drill Files failed
    rmdir /s /q "%TEMP_DIR%" >nul 2>&1
    exit /b 1
)

del /q "%TEMP_DIR%\gerbers\*.gbrjob" >nul 2>&1

REM ###############################################################################
REM Create Gerbers ZIP
REM ###############################################################################

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
echo Files generated:
echo - %PROJECT_NAME%_gerbers.zip
echo - %PROJECT_NAME%_bom.csv
echo - %PROJECT_NAME%_placement.csv
echo.
echo Gerber layers: %GERBER_LAYERS%
) > "%REPORT_FILE%"

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
