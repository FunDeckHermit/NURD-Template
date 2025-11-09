## NURDspace KiCAD template

This repository contains a structured KiCad symbol library designed for consistency and complete manufacturing data integration.  
It standardizes supplier and manufacturer metadata directly within component symbols.

## Overview

- **Total libraries:** 26
- **Total parts:** 1,614
- **Format:** `.kicad_sym` (KiCAD 6+ compatible)  

Libraries are organized by component type for clear structure and efficient design workflow.

## How to Use

### 1. Install the Template

Copy the entire `NURD Template` folder into your KiCad templates directory.

**Windows:**  

```
C:\Users\<username>\Documents\KiCad\<version>\template\
```

**Linux:**  

```
/home/<username>/.local/share/kicad/<version>/template/
```

If the folder doesn’t exist, create it manually.

### 2. Create a Project

1. Open KiCad → *File → New Project → New Project from Template*.  
2. Select **NURD Template**.  
3. Choose a destination folder and project name.  
4. KiCad will create a new project pre-configured with linked symbol and footprint tables.

### 3. Start Designing

The project includes:

- Linked symbol and footprint libraries.  
- Standard DRC/ERC settings.  
- Predefined folder structure for fabrication and outputs.

---

## Custom Attributes (beyond KiCad defaults)

Each component symbol includes structured metadata that supports procurement, documentation, and version control.  
When extending the library it would be nice if these attributes were also filled in. S1 (Source 1) is Mouser.eu in most cases. 

| Attribute          | Description                      |
| ------------------ | -------------------------------- |
| **MPN**            | Manufacturer Part Number         |
| **MF**             | Manufacturer name                |
| **S1 Description** | Supplier’s catalog description   |
| **S1 Part number** | Supplier’s unique part number    |
| **S1 Part link**   | URL to supplier’s product page   |
| **S1 Price @ 100** | Price per unit at quantity 100   |
| **Update date**    | Last update or verification date |

## Notes

- All symbols follow the `NRD_` prefix convention.  
- Use the `..project` library for one-off or project-specific components.  
- You can add new attributes in the KiCad Symbol Editor; they’ll be automatically included in BOM exports.  
- Contributions to extend the attribute set or add verified components are welcome.

