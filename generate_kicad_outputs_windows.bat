@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM  KiCad Production Export  --  Dashboard UI
REM ============================================================================

set "ESC="
set "R=!ESC![0m"
set "BOLD=!ESC![1m"
set "CYAN=!ESC![96m"
set "GREEN=!ESC![92m"
set "RED=!ESC![91m"
set "YELLOW=!ESC![93m"
set "WHITE=!ESC![97m"
set "GREY=!ESC![90m"
set "CLS=!ESC![2J!ESC![H"
set "HIDE=!ESC![?25l"
set "SHOW=!ESC![?25h"

set "SN[1]=Detect layers"
set "SN[2]=Schematic PDF"
set "SN[3]=PCB PDF"
set "SN[4]=Render top"
set "SN[5]=Render bottom"
set "SN[6]=Render isometric"
set "SN[7]=Drill files + map"
set "SN[8]=STEP model"
set "SN[9]=Placement CSV"
set "SN[10]=BOM export"
set "SN[11]=BOM deduplication"
set "SN[12]=Gerbers + drill ZIP"
set "SN[13]=Package + report"

for /l %%i in (1,1,13) do set "SS[%%i]=0"
for /l %%i in (1,1,13) do set "ST[%%i]=0"
for /l %%i in (1,1,13) do set "SD[%%i]=0"
set "MSG="
set "ERRMSG="
set "GLOBAL_DUR=0"

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "RUN_DT=%%i"
call :EPOCH
set "GLOBAL_START=!_EP!"

REM --- KiCad CLI path
set "KICAD_CLI="
for /f "delims=" %%i in ('where kicad-cli.exe 2^>nul') do ( set "KICAD_CLI=%%i" & goto :cli_found )
for %%v in (12.0 11.0 10.0 9.0 8.0) do (
    if exist "C:\Program Files\KiCad\%%v\bin\kicad-cli.exe" (
        set "KICAD_CLI=C:\Program Files\KiCad\%%v\bin\kicad-cli.exe"
        goto :cli_found
    )
)
:cli_found
if "!KICAD_CLI!"=="" (
    echo !RED!ERROR: kicad-cli.exe not found.!R!
    exit /b 1
)

REM --- Dirs
set "OUTPUT_DIR=%~1"
if "!OUTPUT_DIR!"=="" set "OUTPUT_DIR=kicad-artifacts"
set "TEMP_DIR=%TEMP%\kicad-%RANDOM%"
mkdir "!TEMP_DIR!" >nul 2>&1
mkdir "!TEMP_DIR!\gerbers" >nul 2>&1
mkdir "!TEMP_DIR!\drill" >nul 2>&1
set "LOG=!TEMP_DIR!\build.log"

REM --- Project
for %%f in (*.kicad_pro) do set "PROJ=%%f"
for %%f in ("!PROJ!") do set "BASE=%%~nf"
set "PCB=!BASE!.kicad_pcb"
set "SCH=!BASE!.kicad_sch"
set "RW=1400"
set "RH=1400"
set "RQ=high"
set "IR=315,0,45"

REM ============================================================================
REM  STEPS
REM ============================================================================

REM -- 1 Detect layers
call :BEGIN_STEP 1 "Scanning PCB file for copper layers..."
"!KICAD_CLI!" pcb layers "!PCB!" > "!TEMP_DIR!\layers_raw.txt" 2>&1
set "LAYERS=F.Cu,B.Cu,B.Mask,F.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts"
findstr /i "In1\.Cu" "!PCB!" >nul 2>&1 && set "LAYERS=F.Cu,In1.Cu,In2.Cu,B.Cu,B.Mask,F.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts"
findstr /i "In3\.Cu" "!PCB!" >nul 2>&1 && set "LAYERS=F.Cu,In1.Cu,In2.Cu,In3.Cu,In4.Cu,B.Cu,B.Mask,F.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts"
findstr /i "In5\.Cu" "!PCB!" >nul 2>&1 && set "LAYERS=F.Cu,In1.Cu,In2.Cu,In3.Cu,In4.Cu,In5.Cu,In6.Cu,B.Cu,B.Mask,F.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts"
findstr /i "In7\.Cu" "!PCB!" >nul 2>&1 && set "LAYERS=F.Cu,In1.Cu,In2.Cu,In3.Cu,In4.Cu,In5.Cu,In6.Cu,In7.Cu,In8.Cu,B.Cu,B.Mask,F.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts"
call :END_STEP 1

REM -- 2 Schematic PDF
call :BEGIN_STEP 2 "Exporting schematic to PDF..."
"!KICAD_CLI!" sch export pdf "!SCH!" --output "!TEMP_DIR!\!BASE!_schematic.pdf" >> "!LOG!" 2>&1
if !errorlevel! neq 0 ( call :FAIL_STEP 2 "sch export pdf failed" & goto :done )
timeout /t 2 /nobreak >nul
call :END_STEP 2

REM -- 3 PCB PDF
call :BEGIN_STEP 3 "Exporting PCB layout to PDF..."
"!KICAD_CLI!" pcb export pdf "!PCB!" --layers F.Cu,B.Cu --output "!TEMP_DIR!\!BASE!_pcb.pdf" >> "!LOG!" 2>&1
if !errorlevel! neq 0 ( call :FAIL_STEP 3 "pcb export pdf failed" & goto :done )
timeout /t 2 /nobreak >nul
call :END_STEP 3

REM -- 4 Render top
call :BEGIN_STEP 4 "Rendering top side (!RW!x!RH!, !RQ!)..."
"!KICAD_CLI!" pcb render "!PCB!" --side top --quality !RQ! --width !RW! --height !RH! --output "!TEMP_DIR!\!BASE!_render-top.png" >> "!LOG!" 2>&1
if !errorlevel! neq 0 ( call :FAIL_STEP 4 "render top failed" & goto :done )
timeout /t 2 /nobreak >nul
call :END_STEP 4

REM -- 5 Render bottom
call :BEGIN_STEP 5 "Rendering bottom side..."
"!KICAD_CLI!" pcb render "!PCB!" --side bottom --quality !RQ! --width !RW! --height !RH! --output "!TEMP_DIR!\!BASE!_render-bottom.png" >> "!LOG!" 2>&1
if !errorlevel! neq 0 ( call :FAIL_STEP 5 "render bottom failed" & goto :done )
timeout /t 2 /nobreak >nul
call :END_STEP 5

REM -- 6 Render isometric
call :BEGIN_STEP 6 "Rendering isometric view..."
"!KICAD_CLI!" pcb render "!PCB!" --side top --quality !RQ! --width !RW! --height !RH! --rotate !IR! --output "!TEMP_DIR!\!BASE!_render-iso.png" >> "!LOG!" 2>&1
if !errorlevel! neq 0 ( call :FAIL_STEP 6 "render isometric failed" & goto :done )
timeout /t 2 /nobreak >nul
call :END_STEP 6

REM -- 7 Drill files
call :BEGIN_STEP 7 "Exporting drill files and PDF map..."
"!KICAD_CLI!" pcb export drill "!PCB!" --output "!TEMP_DIR!\drill" --format excellon --drill-origin absolute --generate-map --map-format pdf >> "!LOG!" 2>&1
if !errorlevel! neq 0 ( call :FAIL_STEP 7 "drill export failed" & goto :done )
timeout /t 2 /nobreak >nul
for %%f in ("!TEMP_DIR!\drill\*.pdf") do if not "%%~nf"=="!BASE!_drill-map" ren "%%f" "!BASE!_drill-map.pdf"
move "!TEMP_DIR!\drill\*" "!TEMP_DIR!\" >nul 2>&1
rmdir "!TEMP_DIR!\drill" >nul 2>&1
call :END_STEP 7

REM -- 8 STEP model
call :BEGIN_STEP 8 "Exporting 3D STEP model..."
"!KICAD_CLI!" pcb export step "!PCB!" --output "!TEMP_DIR!\!BASE!_board.step" --force >> "!LOG!" 2>&1
if !errorlevel! neq 0 ( call :FAIL_STEP 8 "step export failed" & goto :done )
timeout /t 2 /nobreak >nul
call :END_STEP 8

REM -- 9 Placement
call :BEGIN_STEP 9 "Exporting component placement CSV..."
"!KICAD_CLI!" pcb export pos "!PCB!" --output "!TEMP_DIR!\!BASE!_placement_raw.csv" --format csv --units mm --side both --exclude-dnp >> "!LOG!" 2>&1
if !errorlevel! neq 0 ( call :FAIL_STEP 9 "pos export failed" & goto :done )
timeout /t 2 /nobreak >nul
powershell -NoProfile -Command "& {$c=Get-Content '!TEMP_DIR!\!BASE!_placement_raw.csv';$c[0]='Designator,Val,Package,\"Mid X\",\"Mid Y\",Rotation,Layer';Set-Content '!TEMP_DIR!\!BASE!_placement.csv' $c}" >nul 2>&1
del "!TEMP_DIR!\!BASE!_placement_raw.csv" >nul 2>&1
call :END_STEP 9

REM -- 10 BOM export
call :BEGIN_STEP 10 "Exporting raw BOM from schematic..."
"!KICAD_CLI!" sch export bom "!SCH!" --fields "Reference,Value,MPN,Footprint,^${QUANTITY}" --labels "Designator,Value,MPN,Footprint,Qty" --output "!TEMP_DIR!\bom_raw.csv" >> "!LOG!" 2>&1
timeout /t 2 /nobreak >nul
call :END_STEP 10

REM -- 11 BOM dedup
call :BEGIN_STEP 11 "Deduplicating BOM by MPN..."
powershell -NoProfile -Command "& {$csv=Import-Csv '!TEMP_DIR!\bom_raw.csv';$g=@{};foreach($r in $csv){$m=$r.MPN.Trim();if([string]::IsNullOrWhiteSpace($m)){$k=$r.Designator;$um=$r.MPN}else{$k=$m;$um=$m};if(-not $g.ContainsKey($k)){$g[$k]=[PSCustomObject]@{Designator=@($r.Designator);Value=$r.Value;MPN=$um;Footprint=$r.Footprint;Qty=[int]$r.Qty}}else{$g[$k].Designator+=$r.Designator;$g[$k].Qty+=[int]$r.Qty}};$o=@();foreach($k in ($g.Keys|Sort-Object)){$d=$g[$k].Designator -join ' ';$o+=[PSCustomObject]@{Designator=$d;Value=$g[$k].Value;MPN=$g[$k].MPN;Footprint=$g[$k].Footprint;Qty=$g[$k].Qty}};$o|Export-Csv -Path '!TEMP_DIR!\!BASE!_bom.csv' -NoTypeInformation -Encoding UTF8}" >> "!LOG!" 2>&1
call :END_STEP 11

REM -- 12 Gerbers
call :BEGIN_STEP 12 "Exporting Gerbers and JLCPCB drill files..."
"!KICAD_CLI!" pcb export gerbers "!PCB!" --output "!TEMP_DIR!\gerbers" --layers "!LAYERS!" >> "!LOG!" 2>&1
if !errorlevel! neq 0 ( call :FAIL_STEP 12 "gerber export failed" & goto :done )
timeout /t 2 /nobreak >nul
"!KICAD_CLI!" pcb export drill "!PCB!" --output "!TEMP_DIR!\gerbers" --format excellon --drill-origin absolute --excellon-zeros-format decimal --excellon-units mm --excellon-oval-format route >> "!LOG!" 2>&1
if !errorlevel! neq 0 ( call :FAIL_STEP 12 "gerber drill export failed" & goto :done )
del /q "!TEMP_DIR!\gerbers\*.gbrjob" >nul 2>&1
powershell -NoProfile -Command "Add-Type -AN System.IO.Compression.FileSystem;[IO.Compression.ZipFile]::CreateFromDirectory('!TEMP_DIR!\gerbers','!TEMP_DIR!\!BASE!_gerbers.zip')" >> "!LOG!" 2>&1
rmdir /s /q "!TEMP_DIR!\gerbers" >nul 2>&1
call :END_STEP 12

REM -- 13 Package
call :BEGIN_STEP 13 "Writing report and copying to output..."
call :EPOCH
set /a "GLOBAL_DUR=!_EP! - !GLOBAL_START!"
if exist "!OUTPUT_DIR!" rmdir /s /q "!OUTPUT_DIR!" >nul 2>&1
mkdir "!OUTPUT_DIR!" >nul 2>&1
(
echo KiCad Export Report
echo ===================
echo.
echo Project:  !BASE!
echo Run at:   !RUN_DT!
echo Duration: !GLOBAL_DUR!s
echo.
echo Layer config:
echo   !LAYERS!
echo.
echo Step timings:
) > "!TEMP_DIR!\report.txt"
for /l %%i in (1,1,13) do (
    set "_p=!SN[%%i]!                              "
    set "_p=!_p:~0,30!"
    echo   %%i. !_p! !SD[%%i]!s >> "!TEMP_DIR!\report.txt"
)
(echo. & echo Generated files:) >> "!TEMP_DIR!\report.txt"
for /f "delims=" %%f in ('dir /b "!TEMP_DIR!"') do echo   %%f >> "!TEMP_DIR!\report.txt"
for /f "delims=" %%f in ('dir /b "!TEMP_DIR!"') do move "!TEMP_DIR!\%%f" "!OUTPUT_DIR!\" >nul 2>&1
rmdir /s /q "!TEMP_DIR!" >nul 2>&1
call :END_STEP 13

REM ============================================================================
REM  FINAL SUMMARY
REM ============================================================================
:done
<nul set /p "_=!SHOW!!CLS!"
if "!ERRMSG!"=="" (
    echo !BOLD!!GREEN!  KiCad Export -- Complete!R!
) else (
    echo !BOLD!!RED!  KiCad Export -- Failed!R!
)
echo.
echo !GREY!  Project: !WHITE!!BASE!!R!   !GREY!Output: !WHITE!!OUTPUT_DIR!!R!
echo !GREY!  Total:   !WHITE!!GLOBAL_DUR!s!R!   !GREY!at !WHITE!!RUN_DT!!R!
echo.
echo !GREY!  ------------------------------------------!R!
echo !BOLD!!WHITE!    Step                           Time!R!
echo !GREY!  ------------------------------------------!R!
for /l %%i in (1,1,13) do (
    set "_p=!SN[%%i]!                              "
    set "_p=!_p:~0,30!"
    set "_d=!SD[%%i]!"
    set "_s=!SS[%%i]!"
    if "!_s!"=="2" echo   !GREEN!v!R!  !WHITE!!_p!!R!  !CYAN!!_d!s!R!
    if "!_s!"=="3" echo   !RED!x!R!  !RED!!_p!  FAILED!R!
    if "!_s!"=="0" echo   !GREY!-!R!  !GREY!!_p!  skipped!R!
)
echo !GREY!  ------------------------------------------!R!
if not "!ERRMSG!"=="" (
    echo.
    echo   !RED!Error: !ERRMSG!!R!
    echo   !GREY!See build.log in output folder (if created)!R!
)
if "!ERRMSG!"=="" (
    echo.
    echo !GREY!  Files:!R!
    for /f "delims=" %%f in ('dir /b "!OUTPUT_DIR!" 2^>nul') do echo    !GREY!.!R! %%f
)
echo.

endlocal
exit /b 0

REM ============================================================================
REM  SUBROUTINES
REM ============================================================================
:EPOCH
for /f %%i in ('powershell -NoProfile -Command "[int](Get-Date -UFormat %%s)"') do set "_EP=%%i"
exit /b 0

:BEGIN_STEP
set "_N=%~1"
set "MSG=%~2"
set "SS[!_N!]=1"
call :EPOCH
set "ST[!_N!]=!_EP!"
call :DRAW
exit /b 0

:END_STEP
set "_N=%~1"
set "SS[!_N!]=2"
call :EPOCH
set /a "SD[!_N!]=!_EP! - !ST[!_N!]!"
set "MSG="
call :DRAW
exit /b 0

:FAIL_STEP
set "_N=%~1"
set "ERRMSG=%~2"
set "SS[!_N!]=3"
call :EPOCH
set /a "SD[!_N!]=!_EP! - !ST[!_N!]!"
set "MSG=!RED!FAILED: !ERRMSG!!R!"
call :DRAW
exit /b 0

:DRAW
<nul set /p "_=!HIDE!!CLS!"
echo !BOLD!!CYAN!  KiCad Production Export!R!   !GREY!!RUN_DT!!R!
echo !GREY!  Project: !WHITE!!BASE!!R!   !GREY!Output: !WHITE!!OUTPUT_DIR!!R!
echo.
echo !GREY!  ------------------------------------------!R!
for /l %%i in (1,1,13) do (
    set "_nm=!SN[%%i]!                              "
    set "_nm=!_nm:~0,30!"
    set "_st=!SS[%%i]!"
    if "!_st!"=="0" echo   !GREY!o  !_nm!!R!
    if "!_st!"=="1" echo   !YELLOW!>  !WHITE!!_nm!!R!
    if "!_st!"=="2" (
        set "_d=!SD[%%i]!"
        echo   !GREEN!v  !WHITE!!_nm!!R!  !GREY!!_d!s!R!
    )
    if "!_st!"=="3" echo   !RED!x  !_nm!  FAILED!R!
)
echo !GREY!  ------------------------------------------!R!
echo.
if not "!MSG!"=="" echo   !MSG!
echo.
exit /b 0
