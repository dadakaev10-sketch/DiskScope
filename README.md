<p align="center">
  <img src="Assets/AppIcon-generated.png" width="128" alt="DiskScope app icon">
</p>

<h1 align="center">DiskScope</h1>

<p align="center">
  <strong>Find storage hogs. Understand your Mac. Clean up with confidence.</strong>
</p>

<p align="center">
  <strong>English</strong> · <a href="README.de.md">Deutsch</a>
</p>

<p align="center">
  100% local · Open source · No subscriptions · No automatic deletion
</p>

DiskScope shows you **what is really taking up space on your Mac**. Analyze
Macintosh HD, your home folder, external drives, or any folder and quickly find
large files, space-consuming apps, possible duplicates, and unnecessary data.

Instead of leaving you with cluttered Finder windows or vague storage
categories, DiskScope makes your folder structure easy to understand. See the
size of each area, navigate directly through subfolders, and move selected
items to the Trash while staying in control.

Everything stays on your Mac. DiskScope requires no account, transmits no file
names, and never deletes anything without your confirmation.

## Download and installation

**[Download DiskScope directly as a DMG](https://github.com/dadakaev10-sketch/DiskScope/releases/latest/download/DiskScope.dmg)**

Compatible with **macOS 12 Monterey or later** on Intel and Apple silicon Macs.

You can also find the DMG and all version notes under
[GitHub Releases](https://github.com/dadakaev10-sketch/DiskScope/releases/latest).
Users do **not** need an Apple Developer account to install DiskScope.

The current open-source build has not yet been notarized by Apple. macOS will
therefore show a security warning the first time you open it:

1. Drag `DiskScope.app` from the DMG into the Applications folder.
2. Try to open DiskScope once.
3. If macOS blocks the app, open **System Settings → Privacy & Security**,
   scroll to **Security**, and click **Open Anyway**.
4. Open DiskScope again and grant Full Disk Access once if you want to analyze
   protected folders.

Only download executable files from the official Releases page of this
repository.

## What DiskScope helps you find

- **The biggest storage hogs:** Sort files and folders by size and immediately
  see where your storage is going.
- **The complete folder structure:** Navigate through subfolders, paths, and
  hidden items without losing context.
- **Large applications:** See how much space installed apps actually use and
  move removable apps to the Trash when needed.
- **Possible duplicates:** Find files with matching names and compare their
  sizes, even when they are stored in different folders.
- **Cleanup candidates:** Review large caches, logs, temporary files, and model
  files without automatic deletion.
- **Internal and external storage:** Analyze Macintosh HD, home folders,
  external drives, and freely selected directories.
- **Logical and allocated size:** Compare file size with the storage actually
  allocated on disk.
- **Cached analyses:** Switch between the five most recent scan results without
  scanning every folder again.

## Built for control, not risk

- Real-time progress during scans
- Multi-selection for files and folders
- Finder integration for quick verification
- Items move to the macOS Trash only after confirmation
- Protected system areas cannot be deleted directly
- Built-in German, English, and Spanish language selection
- Fully local processing without a cloud service or user account

## Full Disk Access

On first launch, DiskScope explains how to grant Full Disk Access for protected
macOS folders. For security reasons, only the user can approve this permission.
DiskScope will not ask again as long as the app identity and system permission
remain unchanged.

## Build from source

Building requires macOS 12 Monterey or later and the Apple Command Line Tools.
The build script creates a Universal Binary for Apple silicon and Intel:

```sh
./build.sh
```

The finished app is written to `build/DiskScope.app`.

## License

DiskScope is available under the [MIT License](LICENSE).
