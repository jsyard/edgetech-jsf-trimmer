[CmdletBinding()]
param(
    [Parameter()]
    [string]$InputFolder = (Get-Location).Path,

    [Parameter()]
    [string]$OutputFolder
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$InputFolder = [System.IO.Path]::GetFullPath($InputFolder)

if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
    $OutputFolder = Join-Path $InputFolder "trimmed"
}
else {
    $OutputFolder = [System.IO.Path]::GetFullPath($OutputFolder)
}

if (-not (Test-Path -LiteralPath $InputFolder -PathType Container)) {
    throw "Input folder does not exist: $InputFolder"
}

New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

$files = Get-ChildItem -LiteralPath $InputFolder -Filter "*.jsf" -File

if ($files.Count -eq 0) {
    Write-Warning "No .jsf files found in: $InputFolder"
    return
}

foreach ($file in $files) {
    $inputFile = $file.FullName
    $outputFile = Join-Path $OutputFolder $file.Name

    Write-Host "Checking $($file.Name)..."

    $source = $null
    $destination = $null

    try {
        $source = [System.IO.File]::Open(
            $inputFile,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::Read
        )

        $firstType4000Offset = $null
        $header = New-Object byte[] 16

        while ($source.Position + 16 -le $source.Length) {
            $messageOffset = $source.Position
            $bytesRead = $source.Read($header, 0, $header.Length)

            if ($bytesRead -ne 16) {
                break
            }

            # JSF sync marker 0x1601 is stored little-endian as 01 16.
            if ($header[0] -ne 0x01 -or $header[1] -ne 0x16) {
                Write-Warning "$($file.Name): invalid JSF marker at byte $messageOffset"
                break
            }

            $messageType = [BitConverter]::ToUInt16($header, 4)
            $payloadSize = [BitConverter]::ToUInt32($header, 12)

            if ($messageType -eq 4000) {
                $firstType4000Offset = $messageOffset
                break
            }

            $nextMessage = $source.Position + [int64]$payloadSize

            if ($nextMessage -gt $source.Length) {
                Write-Warning "$($file.Name): truncated message at byte $messageOffset"
                break
            }

            $source.Seek(
                [int64]$payloadSize,
                [System.IO.SeekOrigin]::Current
            ) | Out-Null
        }

        if ($null -eq $firstType4000Offset) {
            Write-Warning "$($file.Name): no valid Type 4000 message found; skipped"
            continue
        }

        $destination = [System.IO.File]::Create($outputFile)

        $source.Seek(
            [int64]$firstType4000Offset,
            [System.IO.SeekOrigin]::Begin
        ) | Out-Null

        $source.CopyTo($destination)

        if ($firstType4000Offset -eq 0) {
            Write-Host "  Already begins with Type 4000; copied unchanged."
        }
        else {
            Write-Host "  Removed $firstType4000Offset leading bytes."
        }
    }
    catch {
        Write-Warning "$($file.Name): $($_.Exception.Message)"
    }
    finally {
        if ($null -ne $destination) {
            $destination.Dispose()
        }

        if ($null -ne $source) {
            $source.Dispose()
        }
    }
}
