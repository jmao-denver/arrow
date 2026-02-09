# Build and Register Arrow Flight SQL ODBC Driver
# Elevates only for registration step

cd C:\git\arrow\cpp
Remove-Item -Recurse -Force build
mkdir build
cd build

cmake .. -G "Visual Studio 17 2022" -A x64 `
  -DVCPKG_TARGET_TRIPLET=x64-windows `
  -DARROW_DEPENDENCY_SOURCE=VCPKG `
  -DARROW_FLIGHT=ON `
  -DVCPKG_MANIFEST_DIR=".." `
  -DARROW_FLIGHT_SQL=ON `
  -DARROW_FLIGHT_SQL_ODBC=ON `
  -DARROW_BUILD_TESTS=OFF `
  -DARROW_PARQUET=OFF `
  -DCMAKE_INSTALL_PREFIX="$env:FLIGHT_SQL_ODBC_INSTALL_DIR" `
  -DX_VCPKG_APPLOCAL_DEPS_INSTALL=ON
