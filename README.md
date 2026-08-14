# EdgeTech JSF Trimmer

A PowerShell utility for repairing EdgeTech eBOSS JSF files that some importers reject when configuration or navigation messages appear before the first acoustic volume.

The script reads the JSF message headers and creates a copy beginning at the first valid **Message Type 4000** (`BossBeamformedVolumeData`) record. It does not search blindly for a byte pattern.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- EdgeTech eBOSS JSF files containing Message Type 4000

## Usage

1. Download `Trim-EdgeTechJsf.ps1`.
2. Put it in the folder containing the `.jsf` files.
3. Open PowerShell in that folder.
4. Run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Trim-EdgeTechJsf.ps1
```

Processed files are written to a `trimmed` subfolder. Source files are never overwritten.

You can also specify folders:

```powershell
.\Trim-EdgeTechJsf.ps1 -InputFolder "C:\Survey\Raw" -OutputFolder "C:\Survey\Trimmed"
```

## Behaviour

For each JSF file, the script:

1. Reads each 16-byte JSF message header.
2. validates the little-endian sync marker `0x1601` (bytes `01 16`);
3. uses the payload length in the header to move between records;
4. locates the first properly framed Type 4000 message;
5. copies that message and everything after it to a new file.

Files already beginning with Type 4000 are copied unchanged. Files with an invalid header, a truncated leading message, or no Type 4000 record are skipped with a warning.

## Important

Keep the original survey files. Test the trimmed copies in the target software before relying on them. Leading configuration and navigation messages are removed, although no Type 4000 acoustic volume is discarded.
