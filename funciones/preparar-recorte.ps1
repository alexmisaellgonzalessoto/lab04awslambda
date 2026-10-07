$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot 'recorte')
try {
  npm ci --os=linux --cpu=x64 --libc=glibc --omit=dev
  if ($LASTEXITCODE -ne 0) { throw 'No se pudieron preparar las dependencias del recorte para AWS Lambda.' }
} finally {
  Pop-Location
}
