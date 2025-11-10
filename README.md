# NURD Symbol Library — KiCad PCM Package

> This repository has shifted from a **KiCad project template** to a **Plugin & Content Manager (PCM) library package**. The instructions below replace the older “new project from template” guidance.

## What this is
A distributable **KiCad library package** that can be installed and updated via **Preferences → Manage Plugins and Content (PCM)**.

**Package includes:**

- `symbols/` — KiCad `.kicad_sym` libraries (required for symbols)
- `footprints/` — optional KiCad `.pretty` footprint libs
- `3dmodels/` — optional STEP/WRL models
- `README.md`
- `metadata.json` — **required** package manifest at the ZIP root

## Quick install

1. Open **KiCad → Preferences → Manage Plugins and Content**.
2. Go to **Repositories → Add Repository** and paste your repository index URL (served by GitHub Pages or any web host), for example:  
   `https://fundeckhermit.github.io/NURD-Template/repository.json`
3. In the **Browse** tab, find **NURD Symbol Library** and click **Install**.
4. After install, symbols/footprints are available via the standard library tables.

> Yu can also install a **local ZIP** (containing the release .zip file) via **Install from File** in PCM.

## CI: automated releases

- **Release workflow:** bumps the version in `metadata.json`, tags `vX.Y.Z`, builds the ZIP, and creates a GitHub Release.
- **Index workflow:** on successful release, computes ZIP size & SHA256, fills JSON templates, and pushes `packages.json` + `repository.json` to **`gh-pages`**.

### Expected files for the index workflow
```
.pcm/
├─ packages.template.json     # PackageArray template
├─ repository.template.json   # Repository template
└─ version.template.json      # Package version template

.github/workflows/
├─ release.yml                # creates the ZIP release
└─ publish-repo-index.yml     # fills templates and publishes to gh-pages
```

## Using the library in KiCad

After installation via PCM, verify in:
- **Preferences → Manage Symbol Libraries** (global/project) — entries for your `.kicad_sym` files
- **Preferences → Manage Footprint Libraries** — entries for `.pretty` directories

You can now place symbols/footprints directly in schematics/PCBs.

## Custom attributes

These standardized properties appear on many symbols to support procurement and documentation. When contributing parts, please fill them in where applicable:

| Attribute          | Description                               |
|--------------------|-------------------------------------------|
| **MPN**            | Manufacturer Part Number                  |
| **MF**             | Manufacturer name                         |
| **S1 Description** | Supplier’s catalog description            |
| **S1 Part number** | Supplier’s unique part number             |
| **S1 Part link**   | URL to supplier’s product page            |
| **S1 Price @ 100** | Price per unit at quantity 100            |
| **Update date**    | Last update or verification date          |

*(S1 = primary supplier, typically Mouser.eu)

## Contributing

- Follow KiCad Library Convention (KLC) where applicable.
- Keep `metadata.json` valid and bump the version for changes.
- For PCM index hosting, ensure CI keeps `packages.json` and `repository.json` in sync with releases.

## License

This library package is released under **MIT**.
