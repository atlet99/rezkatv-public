# RezkaTV webOS

> [!WARNING]  
> This project is an **independent, non-commercial development** and is not affiliated with the "HDRezka" online cinema (hdrezka.ag), its administration, or its owners in any way. The application does not distribute any content; it merely provides a client for accessing the site from Smart TVs.

> [!CAUTION]  
> The use of this software is entirely **at your own risk**. The author of the project bears no legal, financial, or other responsibility for:
>
> - Potential damage to or loss of your data.
> - Blocking of your accounts or IP addresses, or restriction of access to services.
> - The functionality of the application in the event of changes to the site's API or structure.
> - Any other negative consequences that may arise from the use of this application.

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Packaging for webOS](#packaging-for-webos)
- [Deploying via Homebrew Channel / GitHub Pages](#deploying-via-homebrew-channel--github-pages)
- [License](#license)

## Overview

This repository (`rezkatv-public`) contains the necessary wrapper files, assets, and scripts to package the RezkaTV application for LG webOS Smart TVs, as well as the configurations for publishing the repository for the webOS Homebrew Channel.

The packaging system supports two targets:

- **Modern Build**: Optimized for webOS 5.0 and higher (Chrome 68+).
- **Legacy Build**: A backwards-compatible build targeting webOS 3.x - 4.x (Chrome 38 - 53).

## Project Structure

```text
rezkatv-public/
├── .github/workflows/       # GitHub Actions for automated deployment
│   └── pages.yml            # Deploys repository.json to GitHub Pages
├── webos/                   # webOS application metadata and assets
│   ├── assets/              # Directory with application assets
│   ├── appinfo*.json        # Manifest templates for different webOS versions
│   ├── package-webos.sh     # Primary CLI packaging script
│   └── repository.json      # Metadata for the webOS Homebrew Channel
└── README.md                # This documentation file
```

## Packaging for webOS

The repository includes a helper script `webos/package-webos.sh` to automatically clean the staging directory, fix internal paths for the `file://` protocol, inject necessary polyfills, and generate an installable `.ipk` package.

### Prerequisites

Ensure you have `@webos-tools/cli` installed on your machine to build the final package:

```bash
npm install -g @webos-tools/cli
```

_Note: The script also expects the initial web application build output to be present in either `dist/` or `src/legacy/dist/` respectively, along with a valid `package.json` in the project root._

### Building the Package

1. Ensure the source code has been successfully compiled.
2. Run the packaging script and provide the desired build type:

**For webOS 5+ (Modern):**

```bash
./webos/package-webos.sh modern
```

**For webOS 3.x-4.x (Legacy):**

```bash
./webos/package-webos.sh legacy
```

Upon completion, the script will generate an installable package such as `com.rezkatv.app_1.1.29.ipk` (or `com.rezkatv.app_1.1.29_legacy.ipk` for the legacy build) in your current directory.

## Deploying via Homebrew Channel / GitHub Pages

This repository is configured to behave as a custom repository for the [webOS Homebrew Channel](https://rootmy.tv/).

When changes are pushed to `webos/repository.json` on the `main` branch, a GitHub Action (`.github/workflows/pages.yml`) runs automatically. This action isolates the `repository.json` metadata and serves it securely over a lightweight GitHub Pages deployment. By adding the GitHub Pages URL to their Homebrew Channel settings, users can discover and install standard and experimental application updates seamlessly.

## License

MIT License - see [LICENSE](LICENSE) file.
