#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# KiCad Artifact Generation Script
# Commit: 6653fbfa4651c2b271a23c62324b2debf185073e
# Latest: Fix incomplete mv command at end of script
###############################################################################

START_TIME=$(date +%s)
RUN_DATETIME="$(date +"%Y-%m-%d %H:%M:%S")"

OUTPUT_DIR="${1:-kicad-artifacts}"

# Use current directory for temp files when using Flatpak (Flatpak sandboxing issue)
if command -v flatpak >/dev/null 2>&1 && flatpak info org.kicad.KiCad >/dev/null 2>&1; then
    TEMP_DIR=".kicad-build-temp"
    USE_FLATPAK=true
else
    TEMP_DIR=$(mktemp -d)
    USE_FLATPAK=false
fi

echo "Output directory: $OUTPUT_DIR"
echo "Temporary directory: $TEMP_DIR"

###############################################################################
# Check dependencies upfront
###############################################################################

check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "ERROR: Required command '$1' not found. Install with:"
        
        # Detect package manager
        if command -v dnf >/dev/null 2>&1; then
            case "$1" in
                zip) echo "  sudo dnf install zip" ;;
                gawk) echo "  sudo dnf install gawk" ;;
                sed) echo "  sudo dnf install sed" ;;
                find) echo "  sudo dnf install findutils" ;;
                *) echo "  sudo dnf install $1" ;;
            esac
        elif command -v pacman >/dev/null 2>&1; then
            case "$1" in
                zip) echo "  sudo pacman -S zip" ;;
                gawk) echo "  sudo pacman -S gawk" ;;
                sed) echo "  sudo pacman -S sed" ;;
                find) echo "  sudo pacman -S findutils" ;;
                *) echo "  sudo pacman -S $1" ;;
            esac
        elif command -v apt-get >/dev/null 2>&1; then
            case "$1" in
                zip) echo "  sudo apt-get install zip" ;;
                gawk) echo "  sudo apt-get install gawk" ;;
                sed) echo "  sudo apt-get install sed" ;;
                find) echo "  sudo apt-get install findutils" ;;
                *) echo "  sudo apt-get install $1" ;;
            esac
        else
            echo "  Please install $1 using your package manager"
        fi
        exit 1
    fi
}

echo "Checking dependencies…"
check_command "zip"
check_command "gawk"
check_command "sed"
check_command "find"

###############################################################################
# Setup error trap for cleanup on failure
###############################################################################

cleanup_on_error() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo "ERROR: Script failed with exit code $exit_code"
        echo "Cleaning up temporary directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
    fi
    exit $exit_code
}

trap cleanup_on_error EXIT

###############################################################################
# Clean output directory if it already exists
###############################################################################

if [[ -d "$OUTPUT_DIR" ]]; then
    echo "Cleaning existing output directory: $OUTPUT_DIR"
    rm -rf "$OUTPUT_DIR"
fi

###############################################################################
# Detect KiCad CLI (native first, then Flatpak)
###############################################################################

KICAD_CLI=""

if command -v kicad-cli >/dev/null 2>&1; then
    echo "Found native KiCad installation."
    KICAD_CLI="kicad-cli"
fi

if [[ -z "$KICAD_CLI" ]] && command -v flatpak >/dev/null 2>&1; then
    if flatpak info org.kicad.KiCad >/dev/null 2>&1; then
        echo "Found KiCad via Flatpak (org.kicad.KiCad)"
        KICAD_CLI="flatpak run --command=kicad-cli org.kicad.KiCad"
        USE_FLATPAK=true
    elif flatpak info org.kicad_pcb.KiCad >/dev/null 2>&1; then
        echo "Found KiCad via Flatpak (org.kicad_pcb.KiCad)"
        KICAD_CLI="flatpak run --command=kicad-cli org.kicad_pcb.KiCad"
        USE_FLATPAK=true
    fi
fi

if [[ -z "$KICAD_CLI" ]]; then
    echo "ERROR: KiCad not found (native or Flatpak)."
    exit 1
fi

echo "Using KiCad CLI: $KICAD_CLI"

###############################################################################
# Locate project files
###############################################################################

PROJ_FILE=$(find . -maxdepth 1 -type f -name "*.kicad_pro" | head -n 1 || true)
if [[ -z "$PROJ_FILE" ]]; then
    echo "ERROR: No *.kicad_pro file found!"
    exit 1
fi

BASE="${PROJ_FILE%.kicad_pro}"
SCHEMATIC="${BASE}.kicad_sch"
PCB="${BASE}.kicad_pcb"

PROJECT_NAME=$(basename "$BASE")

[[ -f "$SCHEMATIC" ]] || { echo "ERROR: Missing: $SCHEMATIC"; exit 1; }
[[ -f "$PCB" ]]       || { echo "ERROR: Missing: $PCB"; exit 1; }

echo "Project name: $PROJECT_NAME"
echo "Schematic:    $SCHEMATIC"
echo "PCB:          $PCB"

###############################################################################
# Prepare temporary folders
###############################################################################

mkdir -p "$TEMP_DIR/drill"
mkdir -p "$TEMP_DIR/gerbers"

REPORT_FILE="$TEMP_DIR/report.txt"
LOG_FILE="$TEMP_DIR/build.log"

# Start logging
exec > >(tee -a "$LOG_FILE")
exec 2>&1

###############################################################################
# Helper function to wait for file creation
###############################################################################

wait_for_file() {
    local file="$1"
    local timeout="${2:-15}"
    local elapsed=0
    
    while [[ ! -f "$file" ]] && [[ $elapsed -lt $timeout ]]; do
        sleep 0.2
        elapsed=$((elapsed + 1))
    done
    
    if [[ ! -f "$file" ]]; then
        echo "ERROR: File not created after ${timeout}s: $file"
        ls -la "$(dirname "$file")" 2>/dev/null || echo "Directory does not exist: $(dirname "$file")"
        return 1
    fi
}

###############################################################################
# Detect PCB layers from KiCad PCB file
###############################################################################

detect_layers() {
    # Extract layer information from PCB file
    # Look for common layer definitions and build the layer string
    local layers="F.Cu,B.Cu,F.Mask,B.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts"
    
    # Try to detect inner layers
    if grep -q "In1.Cu" "$PCB"; then
        layers="F.Cu,In1.Cu,In2.Cu,B.Cu,F.Mask,B.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts"
    fi
    
    if grep -q "In3.Cu" "$PCB"; then
        layers="F.Cu,In1.Cu,In2.Cu,In3.Cu,B.Cu,F.Mask,B.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts"
    fi
    
    echo "$layers"
}

GERBER_LAYERS=$(detect_layers)
echo "Detected gerber layers: $GERBER_LAYERS"

###############################################################################
# Schematic PDF
###############################################################################

echo "→ Exporting schematic PDF"
if ! $KICAD_CLI sch export pdf "$SCHEMATIC" \
    --output "$TEMP_DIR/${PROJECT_NAME}_schematic.pdf"; then
    echo "ERROR: Exporting schematic PDF failed!"
    exit 1
fi

if ! wait_for_file "$TEMP_DIR/${PROJECT_NAME}_schematic.pdf" 15; then
    exit 1
fi

###############################################################################
# PCB PDF (direct export without multipage)
###############################################################################

echo "→ Exporting PCB PDF"
if ! $KICAD_CLI pcb export pdf "$PCB" \
    --layers F.Cu,B.Cu \
    --output "$TEMP_DIR/${PROJECT_NAME}_pcb.pdf"; then
    echo "ERROR: Exporting PCB PDF failed!"
    exit 1
fi

if ! wait_for_file "$TEMP_DIR/${PROJECT_NAME}_pcb.pdf" 15; then
    exit 1
fi

###############################################################################
# High-quality renders
###############################################################################

RENDER_WIDTH=1400
RENDER_HEIGHT=1400
RENDER_QUALITY="high"

echo "→ Exporting top render"
if ! $KICAD_CLI pcb render "$PCB" \
    --side top \
    --quality "$RENDER_QUALITY" \
    --width "$RENDER_WIDTH" \
    --height "$RENDER_HEIGHT" \
    --output "$TEMP_DIR/${PROJECT_NAME}_render-top.png"; then
    echo "ERROR: Exporting top render failed!"
    exit 1
fi

if ! wait_for_file "$TEMP_DIR/${PROJECT_NAME}_render-top.png" 15; then
    exit 1
fi

echo "→ Exporting bottom render"
if ! $KICAD_CLI pcb render "$PCB" \
    --side bottom \
    --quality "$RENDER_QUALITY" \
    --width "$RENDER_WIDTH" \
    --height "$RENDER_HEIGHT" \
    --output "$TEMP_DIR/${PROJECT_NAME}_render-bottom.png"; then
    echo "ERROR: Exporting bottom render failed!"
    exit 1
fi

if ! wait_for_file "$TEMP_DIR/${PROJECT_NAME}_render-bottom.png" 15; then
    exit 1
fi

###############################################################################
# Isometric render
###############################################################################

ISO_ROTATION="315,0,45"

echo "→ Exporting isometric render"
if ! $KICAD_CLI pcb render "$PCB" \
    --side top \
    --quality "$RENDER_QUALITY" \
    --width "$RENDER_WIDTH" \
    --height "$RENDER_HEIGHT" \
    --rotate "$ISO_ROTATION" \
    --output "$TEMP_DIR/${PROJECT_NAME}_render-iso.png"; then
    echo "ERROR: Exporting isometric render failed!"
    exit 1
fi

if ! wait_for_file "$TEMP_DIR/${PROJECT_NAME}_render-iso.png" 15; then
    exit 1
fi

###############################################################################
# Drill + map
###############################################################################

echo "→ Exporting drill files"
if ! $KICAD_CLI pcb export drill "$PCB" \
    --output "$TEMP_DIR/drill" \
    --format excellon \
    --drill-origin absolute \
    --generate-map \
    --map-format pdf; then
    echo "ERROR: Exporting drill files failed!"
    exit 1
fi

# Wait for drill files
sleep 1
if [[ ! -d "$TEMP_DIR/drill" ]] || [[ -z "$(find "$TEMP_DIR/drill" -maxdepth 1 -type f 2>/dev/null)" ]]; then
    echo "ERROR: No drill files created"
    exit 1
fi

if compgen -G "$TEMP_DIR/drill/*.pdf" > /dev/null; then
    MAPPDF=$(ls "$TEMP_DIR/drill/"*.pdf | head -n 1)
    [[ "$MAPPDF" != *"drill-map.pdf" ]] && mv "$MAPPDF" "$TEMP_DIR/drill/${PROJECT_NAME}_drill-map.pdf"
fi

###############################################################################
# STEP model
###############################################################################

echo "→ Exporting STEP model"
if ! $KICAD_CLI pcb export step "$PCB" \
    --output "$TEMP_DIR/${PROJECT_NAME}_board.step" \
    --force; then
    echo "ERROR: Exporting STEP model failed!"
    exit 1
fi

if ! wait_for_file "$TEMP_DIR/${PROJECT_NAME}_board.step" 15; then
    exit 1
fi

###############################################################################
# XY placement
###############################################################################

echo "→ Exporting placement CSV"
if ! $KICAD_CLI pcb export pos "$PCB" \
    --output "$TEMP_DIR/${PROJECT_NAME}_placement.csv" \
    --side both \
    --format csv \
    --units mm \
    --use-drill-file-origin \
    --exclude-dnp; then
    echo "ERROR: Exporting placement CSV failed!"
    exit 1
fi

if ! wait_for_file "$TEMP_DIR/${PROJECT_NAME}_placement.csv" 15; then
    exit 1
fi

sed -i '1s/Ref,Val,Package,PosX,PosY,Rot,Side/Designator,Val,Package,"Mid X","Mid Y",Rotation,Layer/' "$TEMP_DIR/${PROJECT_NAME}_placement.csv"

###############################################################################
# BOM (KiCad CLI)
###############################################################################

echo "→ Exporting BOM CSV"
if ! $KICAD_CLI sch export bom "$SCHEMATIC" \
    --fields 'Reference,Value,MPN,Footprint,${QUANTITY}' \
    --labels 'Designator, Comment, MPN, Footprint, Quantity' \
    --exclude-dnp \
    --group-by "Value" \
    --ref-range-delimiter "" \
    --output "$TEMP_DIR/${PROJECT_NAME}_bom.csv"; then
    echo "ERROR: Exporting BOM CSV failed!"
    exit 1
fi

if ! wait_for_file "$TEMP_DIR/${PROJECT_NAME}_bom.csv" 15; then
    exit 1
fi

# Fix oversized Designator fields (>2048 chars) for JLCPCB/PCBWay compatibility
gawk -i inplace -F',' 'NR==1 {print; next}
{
  # Extract first quoted field (Designator) and everything after it
  if (match($0, /^"([^"]*)",(.*)$/, a)) {
    refs_str = a[1]          # Raw designator list without quotes
    rest = a[2]              # Everything after first field: ," Comment",...
    
    # Split into individual refs
    n = split(refs_str, refs, ",")
    
    chunk = ""
    for (i = 1; i <= n; i++) {
      test = (chunk == "" ? refs[i] : chunk "," refs[i])
      # Check if QUOTED length would exceed 2048 chars
      if (length("\"" test "\"") > 2048) {
        print "\"" chunk "\"," rest
        chunk = refs[i]
      } else {
        chunk = test
      }
    }
    if (chunk != "") print "\"" chunk "\"," rest
  } else {
    print  # Fallback for malformed lines
  }
}' "$TEMP_DIR/${PROJECT_NAME}_bom.csv"

###############################################################################
# Interactive HTML BOM with command-line flags
###############################################################################

echo "→ Generating Interactive HTML BOM"

# Detect KiCad Python (native first, then Flatpak)
KICAD_PYTHON=""
if python3 -c "import pcbnew" 2>/dev/null; then
    KICAD_PYTHON="python3"
elif [[ "$USE_FLATPAK" == true ]]; then
    KICAD_PYTHON="flatpak run --command=python3 org.kicad.KiCad"
fi

if [[ -z "$KICAD_PYTHON" ]]; then
    echo "⚠ Warning: Could not find KiCad Python with pcbnew, skipping Interactive HTML BOM"
else
    # Install InteractiveHtmlBom
    if [[ "$USE_FLATPAK" == true ]]; then
        flatpak run --command=python3 org.kicad.KiCad -m pip install --user InteractiveHtmlBom jsonschema --quiet 2>&1 || true
    else
        python3 -m pip install --user InteractiveHtmlBom jsonschema --quiet 2>&1 || true
    fi
    
    # Generate Interactive BOM with command-line flags
    echo "→ Running InteractiveHtmlBom generate_interactive_bom..."
    
    if INTERACTIVE_HTML_BOM_CLI_MODE=1 INTERACTIVE_HTML_BOM_NO_DISPLAY=1 \
        $KICAD_PYTHON -m InteractiveHtmlBom.generate_interactive_bom \
        --dest-dir "$TEMP_DIR" \
        --no-browser \
        --show-fields "Value,Footprint,MF,MPN" \
        --group-fields "Value,Footprint" \
        --normalize-field-case \
        --dnp-field "kicad_dnp" \
        --bom-view "left-right" \
        --layer-view "F" \
        --sort-order "C,R,L,D,U,Y,X,F,SW,A,~,HS,CNN,J,P,NT,MH" \
        --blacklist "FID*,MH*" \
        --include-tracks \
        "$PCB" 2>&1 | tee -a "$LOG_FILE"; then
        # Check if HTML was generated
        if find "$TEMP_DIR" -maxdepth 1 -name "*.html" | grep -q .; then
            echo "✓ Interactive BOM generated successfully"
        else
            echo "⚠ Interactive BOM: No HTML files generated"
        fi
    else
        echo "⚠ Warning: Interactive BOM generation failed (see log above)"
    fi
fi

###############################################################################
# Gerbers → ZIP (KiCad 9, JLCPCB-Compatible)
###############################################################################

echo "→ Exporting Gerbers"
if ! $KICAD_CLI pcb export gerbers "$PCB" \
    --output "$TEMP_DIR/gerbers" \
    --layers "$GERBER_LAYERS"; then
    echo "ERROR: Exporting Gerbers failed!"
    exit 1
fi

# Wait for gerber files
sleep 1
if [[ ! -d "$TEMP_DIR/gerbers" ]] || [[ -z "$(find "$TEMP_DIR/gerbers" -maxdepth 1 -type f 2>/dev/null)" ]]; then
    echo "ERROR: No gerber files created"
    exit 1
fi

echo "→ Exporting Drill Files (JLCPCB-compatible Excellon)"
if ! $KICAD_CLI pcb export drill "$PCB" \
    --output "$TEMP_DIR/gerbers" \
    --format excellon \
    --drill-origin absolute \
    --excellon-zeros-format decimal \
    --excellon-units mm \
    --excellon-oval-format route; then
    echo "ERROR: Exporting Drill Files failed!"
    exit 1
fi

echo "→ Removing Gerber Job file (if present)"
rm -f "$TEMP_DIR/gerbers/"*.gbrjob

echo "→ Zipping Gerbers and Drill Files"
(
    cd "$TEMP_DIR/gerbers"
    zip -r "../${PROJECT_NAME}_gerbers.zip" . > /dev/null 2>&1
)
rm -rf "$TEMP_DIR/gerbers"

###############################################################################
# Report.txt
###############################################################################

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "→ Writing report.txt"

cat <<EOF > "$REPORT_FILE"
KiCad Export Report
===================

Project: $PROJECT_NAME
Run at: $RUN_DATETIME
Duration: ${DURATION}s
KiCad Type: $([ "$USE_FLATPAK" = true ] && echo "Flatpak" || echo "Native")

Render settings:
  Quality: $RENDER_QUALITY
  Resolution: ${RENDER_WIDTH}x${RENDER_HEIGHT}
  Isometric rotation: $ISO_ROTATION

Gerber layers:
  $GERBER_LAYERS

Drill:
  Format: Excellon
  Map: PDF

Placement:
  Format: CSV
  Units: mm
  Side: both

Interactive BOM:
  Fields: Value, Footprint, MF, MPN
  Grouped by: Value, Footprint
  DNP filtering: Enabled (kicad_dnp field)
  Layout: left-right
  Layer view: Front

Generated files:
$(ls -1 "$TEMP_DIR")
EOF

###############################################################################
# Move all files from temp to final output directory
###############################################################################

echo "→ Moving files to final output directory"
mkdir -p "$OUTPUT_DIR"
mv "$TEMP_DIR"/* "$OUTPUT_DIR/" 2>/dev/null || true
rmdir "$TEMP_DIR" 2>/dev/null || true

###############################################################################
# Done
###############################################################################

echo ""
echo "✓ All artifacts generated in: $OUTPUT_DIR"
echo "✓ Build log: $OUTPUT_DIR/build.log"
ls -R "$OUTPUT_DIR"
