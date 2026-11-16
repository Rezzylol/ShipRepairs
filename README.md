# Ship of Harkinian for macOS High Sierra (10.13)



A quick non vibe'd note.
i refuse to let my old macbook die, and love zelda.
this hasnt been tested on any other computers nor osx versions.
works fine on mine

With love
Rezzy <3



Patches and a build script that compile [Ship of Harkinian](https://github.com/HarbourMasters/Shipwright) **9.3.1 "Dewey Bravo"** for **macOS 10.13 High Sierra** on Intel Macs. The official macOS release requires macOS 10.15 or later (and is built on Apple Silicon CI), so it won't run on older Macs.

Developed against a 2013 MacBook Air (Intel, HD 5000 graphics).

> **Unofficial and unaffiliated.** This project is not endorsed by or connected to HarbourMasters or the Ship of Harkinian team. Please don't ask them for support with this build.

## Status

- [x] All sources compile on High Sierra with MacPorts clang 17
- [ ] Final link succeeds with the linker flag in `build.sh`
- [ ] Game launches and is playable

Update these boxes as you confirm each step on your machine.

## What you need

- An **Intel Mac running macOS 10.13** (High Sierra)
- **Xcode Command Line Tools**: `xcode-select --install`
- **[MacPorts](https://www.macports.org/install.php)**
- Roughly **10 GB** of free disk space and a few hours (about 1,700 files to compile)
- Your own **Ocarina of Time ROM**. Nothing in this repo includes game data, and none is provided.

## Quick start

```bash
git clone https://github.com/Rezzylol/shipwright-high-sierra.git
cd shipwright-high-sierra
./build.sh
```

The script asks for your password once, to install packages through MacPorts. When it finishes:

```bash
cd ~/soh-build/Shipwright/build-cmake/soh
./soh-macos
```

On first launch the game asks for your ROM so it can extract its assets.

Environment variables you can set:

| Variable | Default | Meaning |
|---|---|---|
| `LLVM_VER` | `17` | MacPorts clang version to use |
| `JOBS` | `2` | Parallel compile jobs (raise it if you have more cores) |
| `WORK` | `~/soh-build` | Where the source and build live |

The script can be re-run safely. It skips what's already done and picks up the build where it stopped.

## What the build does

1. Installs a recent clang and the required libraries via MacPorts.
2. Clones Shipwright at tag `9.3.1` with submodules and applies the patches below.
3. Compiles for `x86_64` with a deployment target of 10.13, using clang's **own libc++** and `-D_LIBCPP_DISABLE_AVAILABILITY`. High Sierra's system C++ library lacks `std::filesystem` and other C++17/20 pieces the code uses.
4. Downloads the official macOS release and copies out `soh.o2r`, the game's resource archive. It is the same on every platform, so it doesn't need to be built from source.

## The patches

| Patch | Why it's needed |
|---|---|
| `0001-soh-deployment-target-10.13.patch` | Lowers `CMAKE_OSX_DEPLOYMENT_TARGET` and the app bundle's minimum OS from 10.15 to 10.13. |
| `0002-libultraship-disable-metal-below-10.15.patch` | The Metal renderer needs 10.15+ APIs. It now reports itself unsupported on older systems, so the game falls back to the **OpenGL** renderer. |
| `0003-soh-speech-nsspeechsynthesizer.patch` | The screen-reader/text-to-speech feature uses `AVSpeechSynthesizer`, which doesn't exist before macOS 10.15. When built against an older SDK it uses `NSSpeechSynthesizer` instead. It uses the default system voice. |

The script also works around three build-system issues, all documented in `build.sh`:

- **Compiler wrappers.** The project overwrites `CMAKE_CXX_FLAGS` in places, so flags passed to CMake get lost. Small wrapper scripts inject `-D_LIBCPP_DISABLE_AVAILABILITY` and the libc++ library path instead.
- **`CMAKE_CXX_SCAN_FOR_MODULES=OFF`.** Newer CMake looks for `clang-scan-deps` when C++20 is on. The project doesn't use modules, so the scan is turned off.
- **`-Wl,-U,_NSBundleResourceRequestLowDiskSpaceNotification`.** The Metal code references a Foundation constant missing from older SDKs. It is declared weak and checked for null at runtime, so the linker is told to allow it.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `'path' is unavailable: introduced in macOS 10.15` | The `_LIBCPP_DISABLE_AVAILABILITY` flag didn't reach the compiler. Re-run `./build.sh` so the wrappers are used. |
| `CMAKE_CXX_COMPILER_CLANG_SCAN_DEPS-NOTFOUND` | Re-run `cmake` with `-DCMAKE_CXX_SCAN_FOR_MODULES=OFF` (already in `build.sh`). |
| `use of undeclared identifier 'AVSpeechSynthesizer'` | Patch 0003 isn't applied. |
| `Undefined symbols ... _NSBundleResourceRequestLowDiskSpaceNotification` | Missing the `-Wl,-U,...` linker flag (already in `build.sh`). |
| `Missing .../include/c++/v1` | That MacPorts clang version doesn't bundle libc++. Try `LLVM_VER=16`. |
| Black screen or crash on launch | Make sure the renderer is set to OpenGL, and open an issue with the Terminal output. |

## Known limitations

- **Intel only.** High Sierra doesn't run on Apple Silicon.
- **Performance.** Older integrated graphics (like the Intel HD 5000) are slow. Lower the internal resolution and avoid extra enhancements.
- **Metal is disabled** below macOS 10.15 by design. OpenGL is used.
- **Text-to-speech** uses the default system voice and ignores the language setting.
- **Pinned to 9.3.1.** Other versions may need different patches.
- The build depends on the MacPorts toolchain staying available for 10.13, which isn't guaranteed.

## Contributing

Issues and pull requests are welcome. If you build this on another old macOS version (10.14 Mojave, say), a note on what worked or didn't is useful.

## Credits and licence

All credit for the game port goes to the [HarbourMasters](https://github.com/HarbourMasters/Shipwright) team and the [libultraship](https://github.com/Kenix3/libultraship) authors. This repo only contains small patches and a build script. It contains no Shipwright source, no binaries, no ROM and no game assets.

The patches modify upstream files, so they are offered under the same terms as those files. See the upstream repositories for their licences. Add a `LICENSE` file for your own build script if you want one.

*The Legend of Zelda: Ocarina of Time* is a trademark of Nintendo. You must provide your own legally obtained ROM.
