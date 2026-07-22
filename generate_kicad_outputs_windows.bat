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

echo [1/15] Step 1: Detecting layers...
echo [%time%] Running kicad-cli pcb layers...
"!KICAD_CLI!" pcb layers "!PCB!" > "!TEMP_DIR!\layers_raw.txt" 2>&1
set "LAYERS=F.Cu,B.Cu,B.Mask,F.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts"
findstr /i "In1\.Cu" "!PCB!" >nul 2>&1 && set "LAYERS=F.Cu,In1.Cu,In2.Cu,B.Cu,B.Mask,F.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts"
findstr /i "In3\.Cu" "!PCB!" >nul 2>&1 && set "LAYERS=F.Cu,In1.Cu,In2.Cu,In3.Cu,In4.Cu,B.Cu,B.Mask,F.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts"
findstr /i "In5\.Cu" "!PCB!" >nul 2>&1 && set "LAYERS=F.Cu,In1.Cu,In2.Cu,In3.Cu,In4.Cu,In5.Cu,In6.Cu,B.Cu,B.Mask,F.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts"
findstr /i "In7\.Cu" "!PCB!" >nul 2>&1 && set "LAYERS=F.Cu,In1.Cu,In2.Cu,In3.Cu,In4.Cu,In5.Cu,In6.Cu,In7.Cu,In8.Cu,B.Cu,B.Mask,F.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts"
echo [%time%] Exit code: !errorlevel!
echo [OK] Layers detected: !LAYERS!

echo.
echo [2/15] Step 2: Calculating PCB PDF scale...
for /f "tokens=1,2,3" %%a in ('powershell -NoProfile -Command "$x=@();$y=@();foreach($l in Get-Content '!PCB!'){if($l -match '\(layer \"Edge.Cuts\"'){ $x0=$true };if($x0 -and $l -match '\(xy\s+(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)'){ $x+=[double]$Matches[1];$y+=[double]$Matches[2] }};$w=($x|Measure-Object -Maximum).Maximum-($x|Measure-Object -Minimum).Minimum;$h=($y|Measure-Object -Maximum).Maximum-($y|Measure-Object -Minimum).Minimum;$s=[math]::Min(150/$h,267/$w);'{0} {1} {2}' -f $w.ToString('0.0',[cultureinfo]::InvariantCulture),$h.ToString('0.0',[cultureinfo]::InvariantCulture),$s.ToString('0.000',[cultureinfo]::InvariantCulture)"') do set "PCB_WIDTH=%%a" & set "PCB_HEIGHT=%%b" & set "PCB_SCALE=%%c"
echo Board: !PCB_WIDTH! x !PCB_HEIGHT! mm, scale: !PCB_SCALE!

echo.
echo [3/15] Step 3: Exporting PCB layout to PDF...
echo [%time%] Running kicad-cli pcb export pdf...
"!KICAD_CLI!" pcb export pdf "!PCB!" --layers "!LAYERS!" --common-layers "Edge.Cuts" --mode-multipage --scale !PCB_SCALE! --output "!TEMP_DIR!\!BASE!_pcb.pdf"
echo [%time%] Exit code: !errorlevel!
if exist "!TEMP_DIR!\!BASE!_pcb.pdf" (echo [OK] PCB PDF created) else (echo [FAIL] PCB PDF MISSING!)

echo.
echo [4/15] Step 4: Exporting schematic to PDF (all sheets)...
echo [%time%] Running kicad-cli sch export pdf...
"!KICAD_CLI!" sch export pdf "!SCH!" --output "!TEMP_DIR!\!BASE!_schematic.pdf" --pages "" >> "!LOG!" 2>&1
echo [%time%] Exit code: !errorlevel!
if exist "!TEMP_DIR!\!BASE!_schematic.pdf" (echo [OK] Schematic PDF created) else (echo [FAIL] Schematic PDF MISSING!)

echo.
echo [5/15] Step 5: Rendering top side...
echo [%time%] Running kicad-cli pcb render --side top...
"!KICAD_CLI!" pcb render "!PCB!" --side top --quality !RQ! --width !RW! --height !RH! --output "!TEMP_DIR!\!BASE!_render-top.png"
echo [%time%] Exit code: !errorlevel!
if exist "!TEMP_DIR!\!BASE!_render-top.png" (echo [OK] Top render created) else (echo [FAIL] Top render MISSING!)

echo.
echo [6/15] Step 6: Rendering bottom side...
echo [%time%] Running kicad-cli pcb render --side bottom...
"!KICAD_CLI!" pcb render "!PCB!" --side bottom --quality !RQ! --width !RW! --height !RH! --output "!TEMP_DIR!\!BASE!_render-bottom.png"
echo [%time%] Exit code: !errorlevel!
if exist "!TEMP_DIR!\!BASE!_render-bottom.png" (echo [OK] Bottom render created) else (echo [FAIL] Bottom render MISSING!)

echo.
echo [7/15] Step 7: Rendering isometric view...
echo [%time%] Running kicad-cli pcb render --rotate !IR!...
"!KICAD_CLI!" pcb render "!PCB!" --side top --zoom 0.7 --quality !RQ! --width !RW! --height !RH! --rotate !IR! --output "!TEMP_DIR!\!BASE!_render-iso.png"
echo [%time%] Exit code: !errorlevel!
if exist "!TEMP_DIR!\!BASE!_render-iso.png" (echo [OK] Isometric render created) else (echo [FAIL] Isometric render MISSING!)

echo.
echo [8/15] Step 8: Exporting drill files and PDF map...
echo [%time%] Running kicad-cli pcb export drill...
"!KICAD_CLI!" pcb export drill "!PCB!" --output "!TEMP_DIR!\drill" --format excellon --drill-origin absolute --generate-map --map-format pdf
echo [%time%] Exit code: !errorlevel!
for %%f in ("!TEMP_DIR!\drill\*.pdf") do if not "%%~nf"=="!BASE!_drill-map" ren "%%f" "!BASE!_drill-map.pdf" >nul 2>&1
move "!TEMP_DIR!\drill\*" "!TEMP_DIR!\" >nul 2>&1
rmdir "!TEMP_DIR!\drill" >nul 2>&1
echo [OK] Drill files exported

echo.
echo [9/15] Step 9: Exporting 3D STEP model...
echo [%time%] Running kicad-cli pcb export step...
"!KICAD_CLI!" pcb export step "!PCB!" --output "!TEMP_DIR!\!BASE!_board.step" --force
echo [%time%] Exit code: !errorlevel!
if exist "!TEMP_DIR!\!BASE!_board.step" (echo [OK] STEP file created) else (echo [FAIL] STEP file MISSING!)

echo.
echo [10/15] Step 10: Exporting component placement CSV...
echo [%time%] Running kicad-cli pcb export pos...
"!KICAD_CLI!" pcb export pos "!PCB!" --output "!TEMP_DIR!\!BASE!_placement_raw.csv" --format csv --units mm --side both --exclude-dnp
echo [%time%] Exit code: !errorlevel!
powershell -NoProfile -Command "& {$c=Get-Content '!TEMP_DIR!\!BASE!_placement_raw.csv';$c[0]='Designator,Val,Package,\"Mid X\",\"Mid Y\",Rotation,Layer';Set-Content '!TEMP_DIR!\!BASE!_placement.csv' $c}" >nul 2>&1
del "!TEMP_DIR!\!BASE!_placement_raw.csv" >nul 2>&1
if exist "!TEMP_DIR!\!BASE!_placement.csv" (echo [OK] Placement CSV created) else (echo [FAIL] Placement CSV MISSING!)

echo.
echo [11/15] Step 11: Exporting raw BOM from schematic...
echo [%time%] Running kicad-cli sch export bom...
"!KICAD_CLI!" sch export bom "!SCH!" --fields "Reference,Value,MPN,Footprint,^${QUANTITY}" --labels "Designator,Value,MPN,Footprint,Qty" --output "!TEMP_DIR!\bom_raw.csv"
echo [%time%] Exit code: !errorlevel!
if exist "!TEMP_DIR!\bom_raw.csv" (echo [OK] bom_raw.csv created) else (echo [FAIL] bom_raw.csv MISSING!)

echo.
echo [12/15] Step 12: Deduplicating BOM by MPN...
echo [%time%] Running PowerShell BOM dedup...
powershell -NoProfile -Command "& {$csv=Import-Csv '!TEMP_DIR!\bom_raw.csv';$g=@{};foreach($r in $csv){$m=$r.MPN.Trim();if([string]::IsNullOrWhiteSpace($m)){$k=$r.Designator;$um=$r.MPN}else{$k=$m;$um=$m};if(-not $g.ContainsKey($k)){$g[$k]=[PSCustomObject]@{Designator=@($r.Designator);Value=$r.Value;MPN=$um;Footprint=$r.Footprint;Qty=[int]$r.Qty}}else{$g[$k].Designator+=$r.Designator;$g[$k].Qty+=[int]$r.Qty}};$o=@();foreach($k in ($g.Keys|Sort-Object)){$d=$g[$k].Designator -join ' ';$o+=[PSCustomObject]@{Designator=$d;Value=$g[$k].Value;MPN=$g[$k].MPN;Footprint=$g[$k].Footprint;Qty=$g[$k].Qty}};$o|Export-Csv -Path '!TEMP_DIR!\!BASE!_bom.csv' -NoTypeInformation -Encoding UTF8}"
echo [%time%] Exit code: !errorlevel!
if exist "!TEMP_DIR!\!BASE!_bom.csv" (echo [OK] BOM CSV created) else (echo [FAIL] BOM CSV MISSING!)

echo.
echo [13/15] Step 13: Exporting Gerbers...
echo [%time%] Running kicad-cli pcb export gerbers...
"!KICAD_CLI!" pcb export gerbers "!PCB!" --output "!TEMP_DIR!\gerbers" --layers "!LAYERS!"
echo [%time%] Exit code: !errorlevel!
dir "!TEMP_DIR!\gerbers\*.gbr" >nul 2>&1 && echo [OK] Gerber files exist || echo [FAIL] Gerber files MISSING!

echo.
echo [14/15] Step 14: Exporting Drills and Creating ZIP...
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

echo.
echo [15/15] Moving files to artifacts...
echo [%time%] Moving files to !OUTPUT_DIR!...
for %%f in ("!TEMP_DIR!\*.*") do (
    echo Moving: %%~nxf
    move "%%f" "!OUTPUT_DIR!\" >nul 2>&1
)

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
pause
rmdir /s /q "!TEMP_DIR!" >nul 2>&1