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
  -DARROW_PARQUET=OFF
  -DCMAKE_INSTALL_PREFIX="$env:FLIGHT_SQL_ODBC_INSTALL_DIR"
  -DX_VCPKG_APPLOCAL_DEPS_INSTALL=ON

cmake --build . --config Debug --target install

# Register ODBC driver
$DLL = (Get-ChildItem -Path . -Filter "arrow_flight_sql_odbc.dll" -Recurse | Select-Object -First 1).FullName

if ($DLL) {
    Write-Host "Registering driver: $DLL"

    # Check if we need elevation for registration
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host "Requesting Administrator privileges for registration..." -ForegroundColor Yellow
        # Run registration commands in elevated PowerShell
        Start-Process powershell -Verb RunAs -ArgumentList "-Command `"reg add 'HKLM\SOFTWARE\ODBC\ODBCINST.INI\Apache Arrow Flight SQL ODBC Driver' /v DriverODBCVer /t REG_SZ /d '03.80' /f; reg add 'HKLM\SOFTWARE\ODBC\ODBCINST.INI\Apache Arrow Flight SQL ODBC Driver' /v UsageCount /t REG_DWORD /d 1 /f; reg add 'HKLM\SOFTWARE\ODBC\ODBCINST.INI\Apache Arrow Flight SQL ODBC Driver' /v Driver /t REG_SZ /d '$DLL' /f; reg add 'HKLM\SOFTWARE\ODBC\ODBCINST.INI\Apache Arrow Flight SQL ODBC Driver' /v Setup /t REG_SZ /d '$DLL' /f; reg add 'HKLM\SOFTWARE\ODBC\ODBCINST.INI\ODBC Drivers' /v 'Apache Arrow Flight SQL ODBC Driver' /t REG_SZ /d 'Installed' /f; Write-Host 'Driver registered successfully!' -ForegroundColor Green; pause`"" -Wait
    } else {
        # Already admin, just run the commands
        reg add "HKLM\SOFTWARE\ODBC\ODBCINST.INI\Apache Arrow Flight SQL ODBC Driver" /v DriverODBCVer /t REG_SZ /d "03.80" /f
        reg add "HKLM\SOFTWARE\ODBC\ODBCINST.INI\Apache Arrow Flight SQL ODBC Driver" /v UsageCount /t REG_DWORD /d 1 /f
        reg add "HKLM\SOFTWARE\ODBC\ODBCINST.INI\Apache Arrow Flight SQL ODBC Driver" /v Driver /t REG_SZ /d $DLL /f
        reg add "HKLM\SOFTWARE\ODBC\ODBCINST.INI\Apache Arrow Flight SQL ODBC Driver" /v Setup /t REG_SZ /d $DLL /f
        reg add "HKLM\SOFTWARE\ODBC\ODBCINST.INI\ODBC Drivers" /v "Apache Arrow Flight SQL ODBC Driver" /t REG_SZ /d "Installed" /f
    }

    Write-Host "Done! Verify with: odbcad32.exe"
} else {
    Write-Host "ERROR: Could not find arrow_flight_sql_odbc.dll"
}


