# Generate Gowin .mi (Memory Initialization) file from firmware binary
# Format: one 32-bit hex word per line, little-endian, padded to 16KB

param(
    [string]$BinFile = "build\optical_flow_fw.bin",
    [string]$MiFile  = "build\optical_flow_fw.mi",
    [int]$SramSizeKB = 16
)

$totalWords = ($SramSizeKB * 1024) / 4  # 4096 words for 16KB

Write-Host "Converting $BinFile -> $MiFile"

$bytes = [System.IO.File]::ReadAllBytes($BinFile)
$lines = New-Object System.Collections.ArrayList

# Convert binary to 32-bit little-endian hex words
for ($i = 0; $i -lt $bytes.Length; $i += 4) {
    [uint32]$w = $bytes[$i]
    if ($i + 1 -lt $bytes.Length) { $w = $w -bor ([uint32]$bytes[$i+1] -shl 8) }
    if ($i + 2 -lt $bytes.Length) { $w = $w -bor ([uint32]$bytes[$i+2] -shl 16) }
    if ($i + 3 -lt $bytes.Length) { $w = $w -bor ([uint32]$bytes[$i+3] -shl 24) }
    [void]$lines.Add($w.ToString('X8'))
}

$fwWords = $lines.Count

# Pad remaining SRAM with zeros
while ($lines.Count -lt $totalWords) {
    [void]$lines.Add('00000000')
}

# Write .mi file
$lines | Set-Content -Path $MiFile -Encoding ASCII

Write-Host "Done!"
Write-Host "  Firmware: $($bytes.Length) bytes ($fwWords words)"
Write-Host "  SRAM:     $($SramSizeKB)KB ($totalWords words)"
Write-Host "  Usage:    $([math]::Round($bytes.Length * 100 / ($SramSizeKB * 1024), 1))%"
Write-Host "  Output:   $MiFile"
