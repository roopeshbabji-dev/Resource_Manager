[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$url = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.6%2B7/OpenJDK21U-jdk_x64_windows_hotspot_21.0.6_7.zip"
$zipPath = "C:\Android\jdk21.zip"
$extractPath = "C:\Android\jdk"

if (-not (Test-Path "C:\Android")) {
    New-Item -ItemType Directory -Path "C:\Android" -Force
}

Write-Host "Downloading OpenJDK 21 LTS..."
Invoke-WebRequest -Uri $url -OutFile $zipPath

Write-Host "Extracting OpenJDK 21 LTS..."
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
Remove-Item -Path $zipPath -Force

$jdkDir = Get-ChildItem -Path $extractPath | Where-Object { $_.PSIsContainer } | Select-Object -First 1
Write-Host "JDK extracted to: $($jdkDir.FullName)"

# Configure Flutter to use JDK 21
& flutter config --jdk-dir="$($jdkDir.FullName)"
& flutter doctor -v
