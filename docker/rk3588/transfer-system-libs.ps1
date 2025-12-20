# Transfer system libraries from sysroot to Ubuntu
$ErrorActionPreference = "Stop"

$SysrootDir = "e:\2025\3_gongkongji\belt_control_system\docker\rk3588\sysroot\pi-root"
$RemoteHost = "192.168.10.155"
$RemoteUser = "linaro"
$RemoteBuildDir = "/home/linaro/belt-control-build/libs"

Write-Host "Transferring system libraries from sysroot..." -ForegroundColor Yellow

# List of required system libraries
$requiredLibs = @(
    "libpulse.so.0",
    "libpulse-simple.so.0",
    "libGLESv2.so.2",
    "libEGL.so.1",
    "libfontconfig.so.1",
    "libglib-2.0.so.0",
    "libxkbcommon.so.0",
    "libpng16.so.16",
    "libharfbuzz.so.0",
    "libfreetype.so.6",
    "libicui18n.so.67",
    "libicuuc.so.67",
    "libicudata.so.67",
    "libpcre2-16.so.0",
    "libbrotlidec.so.1",
    "libbrotlicommon.so.1",
    "libdbus-1.so.3",
    "libX11.so.6",
    "libX11-xcb.so.1",
    "libxcb.so.1",
    "libXau.so.6",
    "libXdmcp.so.6",
    "libbsd.so.0",
    "libmd.so.0",
    "libexpat.so.1",
    "libgraphite2.so.3",
    "libuuid.so.1",
    "libsystemd.so.0",
    "liblzma.so.5",
    "liblz4.so.1",
    "libgcrypt.so.20",
    "libgpg-error.so.0"
)

$count = 0
$notFound = @()

foreach ($libName in $requiredLibs) {
    # Search for the library in sysroot
    $libFile = Get-ChildItem -Recurse -Path $SysrootDir -Filter $libName -File -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($libFile) {
        scp "$($libFile.FullName)" "${RemoteUser}@${RemoteHost}:$RemoteBuildDir/" 2>$null
        $count++
        Write-Host "  [$count] Transferred: $libName" -ForegroundColor DarkGray
    } else {
        $notFound += $libName
        Write-Host "  [!] Not found: $libName" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Total system libraries transferred: $count" -ForegroundColor Green
if ($notFound.Count -gt 0) {
    Write-Host "Not found: $($notFound.Count) libraries" -ForegroundColor Yellow
}
