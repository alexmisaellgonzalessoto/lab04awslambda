param(
  [Parameter(Mandatory = $true)]
  [string]$Url
)

$ErrorActionPreference = 'Stop'
$solicitudImagen = Join-Path $PSScriptRoot 'carga-imagen.json'
Invoke-RestMethod -Uri $Url -Method Post -ContentType 'application/json' -InFile $solicitudImagen
