@echo off
setlocal enabledelayedexpansion

REM --- Find KiCad CLI ---
set "KICAD_CLI="
for /f "delims=" %%i in ('where kicad-cli.exe 2^>nul') do ( set "KICAD_CLI=%%i" & goto :cli_found )
for %%v in (12.0 11.0 10.0 9.0 8.0) do (
    if exist "C:\Program Files\KiCad\%%v\bin\kicad-cli.exe" (
        set "KICAD_CLI=C:\Program Files\KiCad\%%v\bin\kicad-cli.exe"
        goto :cli_found
    )
)
:cli_found
if "!KICAD_CLI!"=="" ( echo ERROR: kicad-cli not found & pause & exit /b 1 )

REM --- Find PCB and SCH ---
set "PCB="
for %%f in (*.kicad_pcb) do set "PCB=%%f"
if "!PCB!"=="" ( echo ERROR: no .kicad_pcb found & pause & exit /b 1 )
for %%f in ("!PCB!") do set "BASE=%%~nf"

REM --- Find schematic matching project name ---
set "SCH=!BASE!.kicad_sch"
if "!SCH!"=="" ( echo ERROR: no .kicad_sch found & pause & exit /b 1 )

REM --- Setup Dirs ---
set "OUTPUT_DIR=kicad-artifacts"
set "LOG=!OUTPUT_DIR!\build.log"
set "TEMP_DIR=%TEMP%\kicad-debug-all-%RANDOM%"
mkdir "!TEMP_DIR!\gerbers" >nul 2>&1
mkdir "!TEMP_DIR!\drill" >nul 2>&1

REM --- Clean output dir for reproducible build ---
if exist "!OUTPUT_DIR!" rmdir /s /q "!OUTPUT_DIR!" >nul 2>&1
mkdir "!OUTPUT_DIR!" >nul 2>&1

set "RW=1400"
set "RH=1400"
set "RQ=high"
set "IR=315,0,45"

REM --- Initialize timing variables ---
set "SCRIPT_START=%time%"

echo ==========================================
echo  KiCad Export Build Script
echo  Started: !SCRIPT_START!
echo ==========================================
echo.

echo [1/15] Step 1: Detecting layers...
set "STEP_START=%time%"
echo [%time%] Running kicad-cli pcb layers...
"!KICAD_CLI!" pcb layers "!PCB!" > "!TEMP_DIR!\layers_raw.txt" 2>&1
set "LAYERS=F.Cu,B.Cu,B.Mask,F.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts"
findstr /i "In1\.Cu" "!PCB!" >nul 2>&1 && set "LAYERS=F.Cu,In1.Cu,In2.Cu,B.Cu,B.Mask,F.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts"
findstr /i "In3\.Cu" "!PCB!" >nul 2>&1 && set "LAYERS=F.Cu,In1.Cu,In2.Cu,In3.Cu,In4.Cu,B.Cu,B.Mask,F.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts"
findstr /i "In5\.Cu" "!PCB!" >nul 2>&1 && set "LAYERS=F.Cu,In1.Cu,In2.Cu,In3.Cu,In4.Cu,In5.Cu,In6.Cu,B.Cu,B.Mask,F.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts"
findstr /i "In7\.Cu" "!PCB!" >nul 2>&1 && set "LAYERS=F.Cu,In1.Cu,In2.Cu,In3.Cu,In4.Cu,In5.Cu,In6.Cu,In7.Cu,In8.Cu,B.Cu,B.Mask,F.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts"
echo [%time%] Exit code: !errorlevel!
echo [OK] Layers detected: !LAYERS!
set "STEP_END=%time%"
call :calculate_time "!STEP_START!" "!STEP_END!" STEP1_MS

echo.
echo [2/15] Step 2: Calculating PCB PDF scale...
set "STEP_START=%time%"
for /f "tokens=1,2,3" %%a in ('powershell -NoProfile -Command "$x=@();$y=@();foreach($l in Get-Content '!PCB!'){if($l -match '\(layer \"Edge.Cuts\"'){ $x0=$true };if($x0 -and $l -match '\(xy\s+(-?\d+([...]
echo Board: !PCB_WIDTH! x !PCB_HEIGHT! mm, scale: !PCB_SCALE!
set "STEP_END=%time%"
call :calculate_time "!STEP_START!" "!STEP_END!" STEP2_MS

echo.
echo [3/15] Step 3: Exporting PCB layout to PDF...
set "STEP_START=%time%"
echo [%time%] Running kicad-cli pcb export pdf...
"!KICAD_CLI!" pcb export pdf "!PCB!" --layers "!LAYERS!" --common-layers "Edge.Cuts" --mode-multipage --scale !PCB_SCALE! --output "!TEMP_DIR!\!BASE!_pcb.pdf"
echo [%time%] Exit code: !errorlevel!
if exist "!TEMP_DIR!\!BASE!_pcb.pdf" (echo [OK] PCB PDF created) else (echo [FAIL] PCB PDF MISSING!)
set "STEP_END=%time%"
call :calculate_time "!STEP_START!" "!STEP_END!" STEP3_MS

echo.
echo [4/15] Step 4: Exporting schematic to PDF (all sheets)...
set "STEP_START=%time%"
echo [%time%] Running kicad-cli sch export pdf...
"!KICAD_CLI!" sch export pdf "!SCH!" --output "!TEMP_DIR!\!BASE!_schematic.pdf" --pages "" >> "!LOG!" 2>&1
echo [%time%] Exit code: !errorlevel!
if exist "!TEMP_DIR!\!BASE!_schematic.pdf" (echo [OK] Schematic PDF created) else (echo [FAIL] Schematic PDF MISSING!)
set "STEP_END=%time%"
call :calculate_time "!STEP_START!" "!STEP_END!" STEP4_MS

echo.
echo [5/15] Step 5: Rendering top side...
set "STEP_START=%time%"
echo [%time%] Running kicad-cli pcb render --side top...
"!KICAD_CLI!" pcb render "!PCB!" --side top --quality !RQ! --width !RW! --height !RH! --output "!TEMP_DIR!\!BASE!_render-top.png"
echo [%time%] Exit code: !errorlevel!
if exist "!TEMP_DIR!\!BASE!_render-top.png" (echo [OK] Top render created) else (echo [FAIL] Top render MISSING!)
set "STEP_END=%time%"
call :calculate_time "!STEP_START!" "!STEP_END!" STEP5_MS

echo.
echo [6/15] Step 6: Rendering bottom side...
set "STEP_START=%time%"
echo [%time%] Running kicad-cli pcb render --side bottom...
"!KICAD_CLI!" pcb render "!PCB!" --side bottom --quality !RQ! --width !RW! --height !RH! --output "!TEMP_DIR!\!BASE!_render-bottom.png"
echo [%time%] Exit code: !errorlevel!
if exist "!TEMP_DIR!\!BASE!_render-bottom.png" (echo [OK] Bottom render created) else (echo [FAIL] Bottom render MISSING!)
set "STEP_END=%time%"
call :calculate_time "!STEP_START!" "!STEP_END!" STEP6_MS

echo.
echo [7/15] Step 7: Rendering isometric view...
set "STEP_START=%time%"
echo [%time%] Running kicad-cli pcb render --rotate !IR!...
"!KICAD_CLI!" pcb render "!PCB!" --side top --zoom 0.7 --quality !RQ! --width !RW! --height !RH! --rotate !IR! --output "!TEMP_DIR!\!BASE!_render-iso.png"
echo [%time%] Exit code: !errorlevel!
if exist "!TEMP_DIR!\!BASE!_render-iso.png" (echo [OK] Isometric render created) else (echo [FAIL] Isometric render MISSING!)
set "STEP_END=%time%"
call :calculate_time "!STEP_START!" "!STEP_END!" STEP7_MS

echo.
echo [8/15] Step 8: Exporting drill files and PDF map...
set "STEP_START=%time%"
echo [%time%] Running kicad-cli pcb export drill...
"!KICAD_CLI!" pcb export drill "!PCB!" --output "!TEMP_DIR!\drill" --format excellon --drill-origin absolute --generate-map --map-format pdf
echo [%time%] Exit code: !errorlevel!
for %%f in ("!TEMP_DIR!\drill\*.pdf") do if not "%%~nf"=="!BASE!_drill-map" ren "%%f" "!BASE!_drill-map.pdf" >nul 2>&1
move "!TEMP_DIR!\drill\*" "!TEMP_DIR!\" >nul 2>&1
rmdir "!TEMP_DIR!\drill" >nul 2>&1
echo [OK] Drill files exported
set "STEP_END=%time%"
call :calculate_time "!STEP_START!" "!STEP_END!" STEP8_MS

echo.
echo [9/15] Step 9: Exporting 3D STEP model...
set "STEP_START=%time%"
echo [%time%] Running kicad-cli pcb export step...
"!KICAD_CLI!" pcb export step "!PCB!" --output "!TEMP_DIR!\!BASE!_board.step" --force
echo [%time%] Exit code: !errorlevel!
if exist "!TEMP_DIR!\!BASE!_board.step" (echo [OK] STEP file created) else (echo [FAIL] STEP file MISSING!)
set "STEP_END=%time%"
call :calculate_time "!STEP_START!" "!STEP_END!" STEP9_MS

echo.
echo [10/15] Step 10: Exporting component placement CSV...
set "STEP_START=%time%"
echo [%time%] Running kicad-cli pcb export pos...
"!KICAD_CLI!" pcb export pos "!PCB!" --output "!TEMP_DIR!\!BASE!_placement_raw.csv" --format csv --units mm --side both --exclude-dnp
echo [%time%] Exit code: !errorlevel!
REM --- Fix CSV header with PowerShell - using file to avoid escaping issues ---
(
powershell -NoProfile -Command "Get-Content '!TEMP_DIR!\!BASE!_placement_raw.csv' | Select-Object -Skip 1" > "!TEMP_DIR!\!BASE!_placement_temp.csv"
) 2>nul
if exist "!TEMP_DIR!\!BASE!_placement_temp.csv" (
    echo Designator,Val,Package,"Mid X","Mid Y",Rotation,Layer > "!TEMP_DIR!\!BASE!_placement.csv"
    type "!TEMP_DIR!\!BASE!_placement_temp.csv" >> "!TEMP_DIR!\!BASE!_placement.csv"
    del "!TEMP_DIR!\!BASE!_placement_temp.csv" >nul 2>&1
    del "!TEMP_DIR!\!BASE!_placement_raw.csv" >nul 2>&1
)
if exist "!TEMP_DIR!\!BASE!_placement.csv" (echo [OK] Placement CSV created) else (echo [FAIL] Placement CSV MISSING!)
set "STEP_END=%time%"
call :calculate_time "!STEP_START!" "!STEP_END!" STEP10_MS

echo.
echo [11/15] Step 11: Exporting raw BOM from schematic...
set "STEP_START=%time%"
echo [%time%] Running kicad-cli sch export bom...
"!KICAD_CLI!" sch export bom "!SCH!" --fields "Reference,Value,MPN,Footprint,^${QUANTITY}" --labels "Designator,Value,MPN,Footprint,Qty" --output "!TEMP_DIR!\bom_raw.csv"
echo [%time%] Exit code: !errorlevel!
if exist "!TEMP_DIR!\bom_raw.csv" (echo [OK] bom_raw.csv created) else (echo [FAIL] bom_raw.csv MISSING!)
set "STEP_END=%time%"
call :calculate_time "!STEP_START!" "!STEP_END!" STEP11_MS

echo.
echo [12/15] Step 12: Deduplicating BOM by MPN...
set "STEP_START=%time%"
echo [%time%] Running PowerShell BOM dedup...
REM --- Create temporary PowerShell script to avoid escaping issues ---
(
echo $csv = Import-Csv '!TEMP_DIR!\bom_raw.csv'
echo $groups = @{}
echo foreach($row in $csv) {
echo     $mpn = $row.MPN.Trim()
echo     if([string]::IsNullOrWhiteSpace($mpn)) {
echo         $key = $row.Designator
echo     } else {
echo         $key = $mpn
echo     }
echo     if($groups.ContainsKey($key)) {
echo         $groups[$key].Qty = [int]$groups[$key].Qty + 1
echo     } else {
echo         $groups[$key] = $row
echo         $groups[$key].Qty = 1
echo     }
echo }
echo $groups.Values ^| Sort-Object Designator ^| Export-Csv '!TEMP_DIR!\!BASE!_bom.csv' -NoTypeInformation
) > "!TEMP_DIR!\bom_process.ps1"
powershell -NoProfile -File "!TEMP_DIR!\bom_process.ps1" >nul 2>&1
echo [%time%] Exit code: !errorlevel!
del "!TEMP_DIR!\bom_process.ps1" >nul 2>&1
if exist "!TEMP_DIR!\!BASE!_bom.csv" (echo [OK] BOM CSV created) else (echo [FAIL] BOM CSV MISSING!)
set "STEP_END=%time%"
call :calculate_time "!STEP_START!" "!STEP_END!" STEP12_MS

echo.
echo [13/15] Step 13: Exporting Gerbers...
set "STEP_START=%time%"
echo [%time%] Running kicad-cli pcb export gerbers...
"!KICAD_CLI!" pcb export gerbers "!PCB!" --output "!TEMP_DIR!\gerbers" --layers "!LAYERS!"
echo [%time%] Exit code: !errorlevel!
dir "!TEMP_DIR!\gerbers\*.gbr" >nul 2>&1 && echo [OK] Gerber files exist || echo [FAIL] Gerber files MISSING!
set "STEP_END=%time%"
call :calculate_time "!STEP_START!" "!STEP_END!" STEP13_MS

echo.
echo [14/15] Step 14: Exporting Drills and Creating ZIP...
set "STEP_START=%time%"
timeout /t 2 /nobreak >nul
echo [%time%] Running kicad-cli pcb export drill...
"!KICAD_CLI!" pcb export drill "!PCB!" --output "!TEMP_DIR!\gerbers" --format excellon --drill-origin absolute --excellon-zeros-format decimal --excellon-units mm --excellon-oval-format route
echo [%time%] Exit code: !errorlevel!

del /q "!TEMP_DIR!\gerbers\*.gbrjob" >nul 2>&1
set "ZIP_FILE=!TEMP_DIR!\!BASE!_gerbers.zip"
if exist "!ZIP_FILE!" del /q "!ZIP_FILE!" >nul 2>&1

echo [%time%] Creating ZIP...
powershell -NoProfile -Command "Compress-Archive -Path '!TEMP_DIR!\gerbers\*' -DestinationPath '!ZIP_FILE!' -Force"
echo [%time%] Exit code: !errorlevel!

if exist "!ZIP_FILE!" (
    echo [OK] ZIP file created
) else (
    echo [FAIL] ZIP file NOT created!
)
set "STEP_END=%time%"
call :calculate_time "!STEP_START!" "!STEP_END!" STEP14_MS

echo.
echo [15/15] Moving files to artifacts...
set "STEP_START=%time%"
echo [%time%] Moving files to !OUTPUT_DIR!...
for %%f in ("!TEMP_DIR!\*.*") do (
    echo Moving: %%~nxf
    move "%%f" "!OUTPUT_DIR!\" >nul 2>&1
)
set "STEP_END=%time%"
call :calculate_time "!STEP_START!" "!STEP_END!" STEP15_MS

echo.
echo ==========================================
echo  Final check of !OUTPUT_DIR!:
echo ==========================================
dir /b "!OUTPUT_DIR!"
echo.

if exist "!OUTPUT_DIR!\!BASE!_gerbers.zip" (
    echo SUCCESS: The ZIP is in the artifacts folder!
) else (
    echo FAILURE: The ZIP is NOT in the artifacts folder.
)

echo.
echo ==========================================
echo  TIMING SUMMARY
echo ==========================================
echo Step 1  - Detecting layers:              !STEP1_MS!
echo Step 2  - Calculating PCB PDF scale:     !STEP2_MS!
echo Step 3  - Exporting PCB PDF:             !STEP3_MS!
echo Step 4  - Exporting Schematic PDF:       !STEP4_MS!
echo Step 5  - Rendering top side:            !STEP5_MS!
echo Step 6  - Rendering bottom side:         !STEP6_MS!
echo Step 7  - Rendering isometric:           !STEP7_MS!
echo Step 8  - Exporting drill files:         !STEP8_MS!
echo Step 9  - Exporting STEP model:          !STEP9_MS!
echo Step 10 - Exporting placement CSV:       !STEP10_MS!
echo Step 11 - Exporting raw BOM:             !STEP11_MS!
echo Step 12 - Deduplicating BOM:             !STEP12_MS!
echo Step 13 - Exporting Gerbers:             !STEP13_MS!
echo Step 14 - Exporting Drills and ZIP:      !STEP14_MS!
echo Step 15 - Moving files to artifacts:     !STEP15_MS!
echo.
echo Script started:  !SCRIPT_START!
echo Script ended:    %time%
echo ==========================================
echo.

pause
rmdir /s /q "!TEMP_DIR!" >nul 2>&1
exit /b 0

REM --- Subroutine: Calculate duration between two times ---
REM --- Input format: HH:MM:SS,CS (e.g., 16:32:51,36) ---
:calculate_time
setlocal
set "START=%~1"
set "END=%~2"
set "RESULT_VAR=%~3"

REM Extract hours, minutes, seconds, centiseconds from start time
for /f "tokens=1,2,3,4 delims=:," %%A in ("!START!") do (
    set /a "S_H=%%A"
    set /a "S_M=%%B"
    set /a "S_S=%%C"
    set /a "S_CS=%%D"
)

REM Extract hours, minutes, seconds, centiseconds from end time
for /f "tokens=1,2,3,4 delims=:," %%A in ("!END!") do (
    set /a "E_H=%%A"
    set /a "E_M=%%B"
    set /a "E_S=%%C"
    set /a "E_CS=%%D"
)

REM Convert to total centiseconds
set /a "S_TOTAL=(S_H*360000)+(S_M*6000)+(S_S*100)+S_CS"
set /a "E_TOTAL=(E_H*360000)+(E_M*6000)+(E_S*100)+E_CS"

REM Handle day wrap-around
if !E_TOTAL! lss !S_TOTAL! (
    set /a "E_TOTAL+=8640000"
)

REM Calculate difference
set /a "DIFF_CS=E_TOTAL-S_TOTAL"
set /a "DIFF_S=DIFF_CS/100"
set /a "DIFF_MS=DIFF_CS%%100"

REM Format output
if !DIFF_S! lss 60 (
    set "DURATION=!DIFF_S!.!DIFF_MS! sec"
) else (
    set /a "DIFF_M=DIFF_S/60"
    set /a "DIFF_S_REM=DIFF_S%%60"
    set "DURATION=!DIFF_M!m !DIFF_S_REM! sec"
)

endlocal & set "%RESULT_VAR%=!DURATION!"
exit /b 0
