$ErrorActionPreference = "Stop"
if (-not (Get-Command Rscript.exe -ErrorAction SilentlyContinue)) {
  throw "Rscript.exe was not found in PATH. Add your R bin directory to PATH or call Rscript.exe with its full path."
}
Rscript.exe .\scripts\VALIDATE_AND_BUILD.R
