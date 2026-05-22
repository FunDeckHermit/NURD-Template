## NURDspace KiCAD template

This is a custom KiCAD symbol library and template for electronics design. It includes electronic parts grouped by type for easy use in circuit design, plus automated scripts for generating manufacturing artifacts.

## 📘 Overview

- **Total libraries:** 26
- **Total parts:** 1,614+
- **Format:** `.kicad_sym` (KiCAD 6+ compatible)
- **KiCAD Version:** 10.0+ (tested with KiCAD 8.0, 9.0, 10.0)
- **Template components:** 4 fiducial markers for PCB assembly

Each library holds parts like resistors, capacitors, diodes, and connectors. They are organised to make schematic design faster and more consistent.

---

## How to Use the Template

This template works with KiCAD's *Create a New Project from Template* feature. It sets up a ready-to-use schematic, PCB, and library configuration for new designs.

### Step 1 — Place the Template Folder

Copy the entire `NURD-template` folder into the KiCAD template directory. The location depends on your operating system and KiCAD version.

**Windows (KiCAD 10.0):**

```
C:\Users\<username>\Documents\KiCad\10.0\template\
```

**Windows (KiCAD 9.0):**

```
C:\Users\<username>\Documents\KiCad\9.0\template\
```

**Linux (KiCAD 10.0):**

```
/home/<username>/.local/share/kicad/10.0/template/
```

**Linux (KiCAD 9.0):**

```
/home/<username>/.local/share/kicad/9.0/template/
```

### Step 2 — Start KiCAD and Create a Project

1. Open KiCAD.
2. Go to **File → New Project → New Project from Template**.
3. Select **NURD-template** from the list.
4. Choose a folder and name for your new project.
5. KiCAD will copy all project files and libraries into the new folder.

### Step 3 — Start Designing

The new project will include:

- A schematic with linked libraries.
- A PCB layout with standard design rules.
- Configured symbol and footprint tables.
- 4 fiducial markers for automated PCB assembly (FID101-FID104).
- Folders for exports and Gerber outputs.

You can now start adding your own components and making changes.

---

## 🔧 Automated Artifact Generation

Two scripts are provided to automatically generate manufacturing artifacts from your KiCAD project.

### Linux/macOS: `generate_kicad_outputs.sh`

Generate all manufacturing and documentation artifacts in one command:

```bash
bash generate_kicad_outputs.sh [output_directory]
```

**Generates (12 outputs):**
- Schematic PDF
- PCB PDF (top & bottom layers)
- Top render (1400x1400 PNG)
- Bottom render (1400x1400 PNG)
- Isometric render (1400x1400 PNG)
- Drill files (Excellon format + PDF map)
- STEP 3D model
- Placement CSV (JLCPCB/PCBWay compatible)
- Bill of Materials CSV
- Gerbers ZIP (all layers + drill files, JLCPCB compatible)
- Build log
- Report

**Supported KiCAD versions:** 8.0, 9.0, 10.0

**Features:**
- Detects inner PCB layers automatically
- Splits large designator fields for JLCPCB compatibility (>2048 char limit)
- Generates interactive HTML BOM (if InteractiveHtmlBom is installed)
- Flatpak support
- Automatic error cleanup

### Windows: `generate_kicad_outputs_windows.bat`

Generate all manufacturing and documentation artifacts on Windows:

```batch
generate_kicad_outputs_windows.bat [output_directory]
```

**Generates (12 outputs):**
- Schematic PDF
- PCB PDF (top & bottom layers)
- Top render (1400x1400 PNG)
- Bottom render (1400x1400 PNG)
- Isometric render (1400x1400 PNG)
- Drill files (Excellon format + PDF map)
- STEP 3D model
- Placement CSV (JLCPCB/PCBWay compatible)
- Bill of Materials CSV
- Gerbers ZIP (all layers + drill files, JLCPCB compatible)
- Build log
- Report

**Supported KiCAD versions:** 8.0, 9.0, 10.0

**Auto-detection:**
- Searches for KiCAD CLI in standard installation paths
- Supports both 64-bit (Program Files) and 32-bit (Program Files x86) installations
- Automatically detects PCB layer configuration

**Usage example:**
```batch
cd path\to\your\project
.\generate_kicad_outputs_windows.bat
```

This creates a `kicad-artifacts` folder with all outputs.

### Output Details

#### Manufacturing Files
- **`*_gerbers.zip`** - Production-ready Gerber files + drill holes (JLCPCB/PCBWay format)
- **`*_placement.csv`** - Pick & place coordinates (JLCPCB compatible headers)
- **`*_bom.csv`** - Bill of Materials with designators, values, MPN, footprints, and quantities

#### Documentation
- **`*_schematic.pdf`** - Full electrical schematic
- **`*_pcb.pdf`** - PCB layer visualization
- **`*_render-top.png`** - Top-side board render
- **`*_render-bottom.png`** - Bottom-side board render
- **`*_render-iso.png`** - Isometric 3D view
- **`*_board.step`** - STEP format 3D model for CAD
- **`*_drill-map.pdf`** - Drill hole reference map
- **report.txt** - Generation summary with layer and settings info

---

## Notes

- The library names start with `.NRD_`.
- The _project library can be used for project-specific parts.
- Based on Roy's MIT licensed NURDspace Library.
- Fiducial markers are set to **exclude from BOM** but **include in position files** for automated assembly.
- For JLCPCB/PCBWay orders, use the `*_gerbers.zip`, `*_placement.csv`, and `*_bom.csv` files directly.
