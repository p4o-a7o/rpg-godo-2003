## RPGGodo2003

made so you can always play ynfg with someone else

(i want cu so bad)

## windows compilation

```powershell
git clone https://github.com/microsoft/vcpkg.git
cd vcpkg; .\bootstrap-vcpkg.bat
$env:VCPKG_ROOT="vcpkg"
$env:PATH="$env:VCPKG_ROOT;$env:PATH"
vcpkg integrate install

add to User Settings (JSON):
    "cmake.configureSettings": {
        "CMAKE_TOOLCHAIN_FILE": "vcpkg/scripts/buildsystems/vcpkg.cmake"
    }

:: debug:

& "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe" -B build -S . -DCMAKE_TOOLCHAIN_FILE="vcpkg/scripts/buildsystems/vcpkg.cmake" `
   -DVCPKG_TARGET_TRIPLET="x64-windows-static" `
   -DVCPKG_INSTALLED_DIR="C:\proj\vcpkg_installed"

& "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe" --build "C:\proj\build" --config Debug --target easyrpg_godot --verbose 2>&1

:: release:

& "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"  -B build -S . `
  -DCMAKE_BUILD_TYPE=Release `
  -DVCPKG_TARGET_TRIPLET="x64-windows-static" `
  -DCMAKE_TOOLCHAIN_FILE="vcpkg/scripts/buildsystems/vcpkg.cmake"

& "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe" --build "C:\proj\build" --config Release --target easyrpg_godot --verbose 2>&1

:: stripped export example:

godot-4.6.2-stable>scons platform=windows target=template_release profile="C:\proj\demo\custom.py" build_profile="C:\proj\demo\stripped.gdbuild"
```

## macos compilation

```bash
# install required binaries (list is not full, i forgor)
brew install pixman libpng zlib fmt cmake

# 2. configure & build
rm -rf build && \
  PKG_CONFIG_PATH="/opt/homebrew/opt/icu4c@78/lib/pkgconfig:/opt/homebrew/lib/pkgconfig:$PKG_CONFIG_PATH" \
  cmake -B build \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_C_COMPILER=/opt/homebrew/opt/llvm/bin/clang \
    -DCMAKE_CXX_COMPILER=/opt/homebrew/opt/llvm/bin/clang++ \
    -DPLAYER_TARGET_PLATFORM=godot \
    -DPLAYER_BUILD_LIBLCF=ON \
    -DPLAYER_ENABLE_TESTS=OFF \
    -DBUILD_SHARED_LIBS=OFF \
    -DICU_ROOT=/opt/homebrew/opt/icu4c@78 \
    -DCMAKE_PREFIX_PATH="/opt/homebrew/opt/icu4c@78;/opt/homebrew/opt/llvm;/opt/homebrew" \
    -DCMAKE_IGNORE_PATH="/Library/Frameworks/Mono.framework/Headers;/Library/Frameworks/Mono.framework" && \
  cmake --build build --parallel
```

## linux compilation

```sh
sudo apt install libopus-dev libmpg123-dev libpixman-1-dev libexpat1-dev pkg-config libinih-dev libicu-dev libpng-dev libfmt-dev

mkdir build && cd build

#debug
cmake -DCMAKE_BUILD_TYPE=Debug ..
cmake --build . --config Debug

# release
cmake ..
cmake --build .
```

---

gotta make builds less hacky later..
