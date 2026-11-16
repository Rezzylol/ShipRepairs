#!/bin/bash
# Build Ship of Harkinian 9.3.1 (Dewey Bravo) for macOS 10.13 High Sierra (Intel).
# Run this ON the Mac:  ./build.sh   (patches are read from ./patches next to this script)
# UNTESTED: written without access to a High Sierra machine. Read README.md first.
set -euo pipefail

LLVM_VER="${LLVM_VER:-17}"                 # MacPorts clang version to use
LLVM="/opt/local/libexec/llvm-${LLVM_VER}"
PATCH_DIR="$(cd "$(dirname "$0")" && pwd)/patches"
WORK="${WORK:-$HOME/soh-build}"
JOBS="${JOBS:-2}"                          # 2013 Air is dual-core; raise if you like

[ "$(uname -m)" = "x86_64" ] || { echo "Intel Mac required"; exit 1; }
command -v port >/dev/null || { echo "Install MacPorts first: https://www.macports.org/install.php"; exit 1; }
xcode-select -p >/dev/null 2>&1 || { echo "Run: xcode-select --install"; exit 1; }

echo "==> Installing build tools and libraries via MacPorts (long)"
sudo port install cmake ninja pkgconfig git python311 "clang-${LLVM_VER}" \
  libsdl2 libsdl2_net libpng glew libzip nlohmann-json tinyxml2 libogg libopus opusfile libvorbis

[ -d "$LLVM/include/c++/v1" ] || { echo "Missing $LLVM/include/c++/v1 - this clang port has no bundled libc++. Try another LLVM_VER."; exit 1; }
LIBCXX_DYLIB="$(find "$LLVM" -name libc++.dylib 2>/dev/null | head -1)"
[ -n "$LIBCXX_DYLIB" ] || { echo "Could not find libc++.dylib under $LLVM"; exit 1; }
LIBCXX_DIR="$(dirname "$LIBCXX_DYLIB")"
echo "Using libc++ from $LIBCXX_DIR"

# The project overwrites CMAKE_CXX_FLAGS in places (e.g. torch/CMakeLists.txt), so flags passed to cmake get lost.
# Wrapper compilers inject the needed flags no matter what the project does.
WRAP="$WORK/wrappers"
mkdir -p "$WRAP"
for tool in clang clang++; do
cat > "$WRAP/$tool" <<WEOF
#!/bin/bash
exec "$LLVM/bin/$tool" -D_LIBCPP_DISABLE_AVAILABILITY -Wno-unused-command-line-argument -L"$LIBCXX_DIR" -Wl,-rpath,"$LIBCXX_DIR" -Wl,-rpath,/opt/local/lib "\$@"
WEOF
chmod +x "$WRAP/$tool"
done

echo "==> Fetching source (9.3.1)"
mkdir -p "$WORK" && cd "$WORK"
[ -d Shipwright ] || git clone --branch 9.3.1 --recursive https://github.com/HarbourMasters/Shipwright.git
cd Shipwright
git submodule update --init --recursive

echo "==> Applying patches"
apply_patch() {  # apply_patch <dir> <patch file>
  if git -C "$1" apply --reverse --check "$2" 2>/dev/null; then
    echo "  already applied: $(basename "$2")"
  else
    git -C "$1" apply "$2" && echo "  applied: $(basename "$2")"
  fi
}
apply_patch . "$PATCH_DIR/0001-soh-deployment-target-10.13.patch"
apply_patch . "$PATCH_DIR/0003-soh-speech-nsspeechsynthesizer.patch"
apply_patch libultraship "$PATCH_DIR/0002-libultraship-disable-metal-below-10.15.patch"

echo "==> Configuring"
rm -rf build-cmake/CMakeCache.txt build-cmake/CMakeFiles
cmake -H. -Bbuild-cmake -GNinja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=x86_64 -DCMAKE_OSX_DEPLOYMENT_TARGET=10.13 \
  -DCMAKE_PREFIX_PATH=/opt/local \
  -DCMAKE_C_COMPILER="$WRAP/clang" -DCMAKE_CXX_COMPILER="$WRAP/clang++" \
  -DCMAKE_OBJC_COMPILER="$WRAP/clang" -DCMAKE_OBJCXX_COMPILER="$WRAP/clang++" \
  -DCMAKE_CXX_SCAN_FOR_MODULES=OFF \
  -DCMAKE_EXE_LINKER_FLAGS="-Wl,-U,_NSBundleResourceRequestLowDiskSpaceNotification"

echo "==> Getting soh.o2r from the official macOS release (it is platform-independent)"
mkdir -p build-cmake/soh && cd build-cmake/soh
if [ ! -f soh.o2r ]; then
  curl -L -o mac.zip https://github.com/HarbourMasters/Shipwright/releases/download/9.3.1/SoH-Dewey-Bravo-Mac.zip
  unzip -oq mac.zip -d mac-release
  O2R="$(find mac-release -name soh.o2r | head -1)"
  if [ -z "$O2R" ]; then
    DMG="$(find mac-release -name '*.dmg' | head -1)"
    [ -n "$DMG" ] && hdiutil attach "$DMG" -mountpoint /tmp/sohdmg -nobrowse -quiet \
      && O2R="$(find /tmp/sohdmg -name soh.o2r | head -1)" && cp "$O2R" soh.o2r && hdiutil detach /tmp/sohdmg -quiet
  else
    cp "$O2R" soh.o2r
  fi
fi
[ -f soh.o2r ] || { echo "Could not obtain soh.o2r - copy it into $PWD manually."; exit 1; }
cd ../..

echo "==> Building (expect a couple of hours on a 2013 Air)"
cmake --build build-cmake -j"$JOBS"

echo
echo "Done. Run:  cd $WORK/Shipwright/build-cmake/soh && ./soh-macos"
echo "First launch asks for your own OoT ROM to extract assets."
