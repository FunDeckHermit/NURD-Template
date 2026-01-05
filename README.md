## NURDspace KiCAD template

This is a custom KiCAD symbol library.
 It includes electronic parts grouped by type for easy use in circuit design.

## 📘Overview

- **Total libraries:** 26
- **Total parts:** 1,614
- **Format:** `.kicad_sym` (KiCAD 6+ compatible)  

Each library holds parts like resistors, capacitors, diodes, and connectors. They are organised to make schematic design faster and more consistent.

---

## How to Use the Template

This template works with KiCAD’s *Create a New Project from Template* feature.
 It sets up a ready-to-use schematic, PCB, and library configuration for new designs.

### Step 1 — Place the Template Folder

Copy the entire `NURDspace Template` folder into the KiCAD template directory.
The location depends on your operating system.

**Windows:**

```
C:\Users\<username>\Documents\KiCad\9.0\template\
```

**Linux:**

```
/home/<username>/.local/share/kicad/9.0/template/
```

### Step 2 — Start KiCAD and Create a Project

1. Open KiCAD.
2. Go to **File → New Project → New Project from Template**.
3. Select **NURDspace Template** from the list.
4. Choose a folder and name for your new project.
5. KiCAD will copy all project files and libraries into the new folder.

### Step 3 — Start Designing

The new project will include:

- A schematic with linked libraries.
- A PCB layout with standard design rules.
- Configured symbol and footprint tables.
- Folders for BOM, Exports, and Gerbers.

You can now start adding your own components and making changes.

## Notes

- The library names start with `.NRD_`.
- The _project library can be used for project specific parts
- Based on Roy's MIT licensed NURDspace Library
