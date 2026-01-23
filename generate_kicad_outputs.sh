#!/usr/bin/env bash
set -euo pipefail

START_TIME=$(date +%s)
RUN_DATETIME="$(date +"%Y-%m-%d %H:%M:%S")"

OUTPUT_DIR="${1:-kicad-artifacts}"

echo "Output directory: ${OUTPUT_DIR}"

###############################################################################
# Clean output directory if it already exists
###############################################################################

if [[ -d "$OUTPUT_DIR" ]]; then
    echo "Cleaning existing output directory: $OUTPUT_DIR"
    rm -rf "$OUTPUT_DIR"
fi

mkdir -p "$OUTPUT_DIR"

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
    elif flatpak info org.kicad_pcb.KiCad >/dev/null 2>&1; then
        echo "Found KiCad via Flatpak (org.kicad_pcb.KiCad)"
        KICAD_CLI="flatpak run --command=kicad-cli org.kicad_pcb.KiCad"
    fi
fi

if [[ -z "$KICAD_CLI" ]]; then
    echo "ERROR: KiCad not found (native or Flatpak)."
    exit 1
fi

echo "Using KiCad CLI: $KICAD_CLI"

###############################################################################
# Ensure zip exists
###############################################################################

if ! command -v zip >/dev/null 2>&1; then
    echo "ERROR: zip command not found. Install with:"
    echo "  sudo apt-get install zip"
    exit 1
fi

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

[[ -f "$SCHEMATIC" ]] || { echo "Missing: $SCHEMATIC"; exit 1; }
[[ -f "$PCB" ]]       || { echo "Missing: $PCB"; exit 1; }

echo "Project name: $PROJECT_NAME"
echo "Schematic:    $SCHEMATIC"
echo "PCB:          $PCB"

###############################################################################
# Prepare folders
###############################################################################

mkdir -p "$OUTPUT_DIR/drill"
mkdir -p "$OUTPUT_DIR/gerbers"
MP_DIR="$OUTPUT_DIR/pcb-multipage"
mkdir -p "$MP_DIR"

REPORT_FILE="$OUTPUT_DIR/report.txt"

###############################################################################
# Schematic PDF
###############################################################################

echo "Exporting schematic PDF…"
$KICAD_CLI sch export pdf "$SCHEMATIC" \
    --output "$OUTPUT_DIR/${PROJECT_NAME}_schematic.pdf"

###############################################################################
# PCB PDF (multipage workaround)
###############################################################################

echo "Exporting PCB PDF…"
$KICAD_CLI pcb export pdf "$PCB" \
    --layers F.Cu,In1.Cu,In2.Cu,B.Cu \
    --mode-multipage \
    --output "$MP_DIR"

INNER_PDF=$(find "$MP_DIR" -maxdepth 1 -type f -name '*.pdf' | head -n 1 || true)
if [[ -z "$INNER_PDF" ]]; then
    echo "ERROR: PCB PDF not generated!"
    exit 1
fi

mv "$INNER_PDF" "$OUTPUT_DIR/${PROJECT_NAME}_pcb.pdf"
rm -rf "$MP_DIR"

###############################################################################
# High-quality renders
###############################################################################

echo "Exporting high-quality top/bottom renders…"

RENDER_WIDTH=1400
RENDER_HEIGHT=1400
RENDER_QUALITY="high"

$KICAD_CLI pcb render "$PCB" \
    --side top \
    --quality "$RENDER_QUALITY" \
    --width "$RENDER_WIDTH" \
    --height "$RENDER_HEIGHT" \
    --output "$OUTPUT_DIR/${PROJECT_NAME}_render-top.png"

$KICAD_CLI pcb render "$PCB" \
    --side bottom \
    --quality "$RENDER_QUALITY" \
    --width "$RENDER_WIDTH" \
    --height "$RENDER_HEIGHT" \
    --output "$OUTPUT_DIR/${PROJECT_NAME}_render-bottom.png"

###############################################################################
# Isometric render
###############################################################################

echo "Exporting high-quality isometric render…"

ISO_ROTATION="315,0,45"

$KICAD_CLI pcb render "$PCB" \
    --side top \
    --quality "$RENDER_QUALITY" \
    --width "$RENDER_WIDTH" \
    --height "$RENDER_HEIGHT" \
    --rotate "$ISO_ROTATION" \
    --output "$OUTPUT_DIR/${PROJECT_NAME}_render-iso.png"

###############################################################################
# Drill + map
###############################################################################

echo "Exporting drill files…"
$KICAD_CLI pcb export drill "$PCB" \
    --output "$OUTPUT_DIR/drill" \
    --format excellon \
    --drill-origin absolute \
    --generate-map \
    --map-format pdf

if compgen -G "$OUTPUT_DIR/drill/*.pdf" > /dev/null; then
    MAPPDF=$(ls "$OUTPUT_DIR/drill/"*.pdf | head -n 1)
    mv "$MAPPDF" "$OUTPUT_DIR/drill/${PROJECT_NAME}_drill-map.pdf"
fi

###############################################################################
# STEP model
###############################################################################

echo "Exporting STEP model…"
$KICAD_CLI pcb export step "$PCB" \
    --output "$OUTPUT_DIR/${PROJECT_NAME}_board.step" \
    --force

###############################################################################
# XY placement
###############################################################################

echo "Exporting placement CSV…"
$KICAD_CLI pcb export pos "$PCB" \
    --output "$OUTPUT_DIR/${PROJECT_NAME}_placement.csv" \
    --side both \
    --format csv \
    --units mm \
    --use-drill-file-origin

###############################################################################
# BOM
###############################################################################

echo "Exporting BOM CSV…"
$KICAD_CLI sch export bom "$SCHEMATIC" \
    --output "$OUTPUT_DIR/${PROJECT_NAME}_bom.csv"

###############################################################################
# Gerbers → ZIP (KiCad 9, JLCPCB-Compatible)
###############################################################################

GERBER_LAYERS="F.Cu,In1.Cu,In2.Cu,B.Cu,F.Mask,B.Mask,F.Paste,B.Paste,F.SilkS,B.SilkS,Edge.Cuts"

echo "Exporting Gerbers…"
$KICAD_CLI pcb export gerbers "$PCB" \
    --output "$OUTPUT_DIR/gerbers" \
    --layers "$GERBER_LAYERS"

echo "Exporting Drill Files (JLCPCB-compatible Excellon)…"
$KICAD_CLI pcb export drill "$PCB" \
    --output "$OUTPUT_DIR/gerbers" \
    --format excellon \
    --drill-origin absolute \
    --excellon-zeros-format decimal \
    --excellon-units mm \
    --excellon-oval-format route

echo "Removing Gerber Job file (if present)…"
rm -f "$OUTPUT_DIR/gerbers/"*.gbrjob

echo "Zipping Gerbers and Drill Files…"
(
    cd "$OUTPUT_DIR/gerbers"
    zip -r "../${PROJECT_NAME}_gerbers.zip" .
)
rm -rf "$OUTPUT_DIR/gerbers"

###############################################################################
# Report.txt
###############################################################################

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "Writing report.txt…"

cat <<EOF > "$REPORT_FILE"
KiCad Export Report
===================

Project: $PROJECT_NAME
Run at: $RUN_DATETIME
Duration: ${DURATION}s

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

Generated files:
$(ls "$OUTPUT_DIR")
EOF

###############################################################################
# Done
###############################################################################

echo ""
echo "All artifacts generated in: $OUTPUT_DIR"
ls -R "$OUTPUT_DIR"
