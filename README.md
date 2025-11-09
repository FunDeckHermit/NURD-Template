# NURD Symbol Library — KiCad PCM Package

> This repository has shifted from a **KiCad project template** to a **Plugin & Content Manager (PCM) library package**. The instructions below replace the older “new project from template” guidance. fileciteturn1file0

## What this is
A distributable **KiCad library package** that can be installed and updated via **Preferences → Manage Plugins and Content (PCM)**. It provides standardized symbol metadata for consistent BOMs and sourcing.

**Package may include:**
- `symbols/` — KiCad `.kicad_sym` libraries (required for symbols)
- `footprints/` — optional KiCad `.pretty` footprint libs
- `3dmodels/` — optional STEP/WRL models
- `README.md`
- `metadata.json` — **required** package manifest at the ZIP root

## Quick install (end users)

1. Open **KiCad → Preferences → Manage Plugins and Content**.
2. Go to **Repositories → Add Repository** and paste your repository index URL (served by GitHub Pages or any web host), for example:  
   `https://<your-user>.github.io/<your-repo>/repository.json`
3. In the **Browse** tab, find **NURD Symbol Library** and click **Install**.
4. After install, symbols/footprints are available via the standard library tables.

> If you don’t run a repository index, you can also install a **local ZIP** (containing `metadata.json` at its root) via **Install from File** in PCM.

## Release packaging (maintainers)

When creating a release, produce a ZIP with this **exact root layout**:
```
nurd-template-<version>.zip
├─ symbols/         # one or more .kicad_sym files
├─ footprints/      # optional .pretty dirs
├─ 3dmodels/        # optional .step/.stp/.wrl
├─ README.md
└─ metadata.json    # REQUIRED, at ZIP root
```

### `metadata.json` (package manifest)
- Lives at the **ZIP root**.
- Describes name, identifier, license, author, and a **versions** array with at least:
  - `version`: semantic version (e.g., `0.1.0`)
  - `status`: e.g., `testing` or `stable`
  - `kicad_version`: minimum KiCad major (e.g., `7.0` or `8.0`)

### Public repository index (for PCM “Add Repository”)
Host two small JSON files on a web server (commonly your repo’s **`gh-pages`** branch):

1. **`packages.json`** — array of packages with their `versions` (each version includes `download_url`, `download_sha256`, `download_size`, `install_size`).
2. **`repository.json`** — points to `packages.json` via a resource object and includes metadata (name, update timestamp).

> Both files should adhere to the KiCad **PCM v1** schema. Your CI can generate them automatically from the **latest GitHub Release** ZIP and publish to `gh-pages`.

## CI: automated releases and index publishing (recommended)

- **Release workflow:** bumps the version in `metadata.json`, tags `vX.Y.Z`, builds the ZIP, and creates a GitHub Release.
- **Index workflow:** on successful release, computes ZIP size & SHA256, fills JSON templates, and pushes `packages.json` + `repository.json` to **`gh-pages`**.

### Expected files for the index workflow
```
.pcm/
├─ packages.template.json     # PackageArray template (uses $VERSION, $DOWNLOAD_URL, …)
└─ repository.template.json   # Repository template (uses $PACKAGES_URL, …)

.github/workflows/
├─ release.yml                # creates the ZIP release
└─ publish-repo-index.yml     # fills templates and publishes to gh-pages
```

## Using the library in KiCad

After installation via PCM, verify in:
- **Preferences → Manage Symbol Libraries** (global/project) — entries for your `.kicad_sym` files
- **Preferences → Manage Footprint Libraries** — entries for `.pretty` directories (if supplied)

You can now place symbols/footprints directly in schematics/PCBs.

## Custom attributes (beyond KiCad defaults)

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

*(S1 = primary supplier, typically Mouser.eu.)* fileciteturn1file0

## Contributing

- Follow KiCad Library Convention (KLC) where applicable.
- Keep `metadata.json` valid and bump the version for changes.
- For PCM index hosting, ensure CI keeps `packages.json` and `repository.json` in sync with releases.

## License

This library package is released under **MIT**.
