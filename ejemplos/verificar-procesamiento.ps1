param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$Bucket,
    [Parameter(Mandatory = $true)][string]$RutaRecorte,
    [string]$Perfil = 'lab04awslambda',
    [string]$Region = 'us-east-1'
)

$ErrorActionPreference = 'Stop'
$respuesta = Invoke-RestMethod -Method Post -Uri $Url -ContentType 'application/json' -InFile (Join-Path $PSScriptRoot 'carga-imagen.json')
if (-not $respuesta.clave.StartsWith('uploads/')) {
    throw 'La respuesta de carga no contiene una clave de imagen original válida.'
}

$claveRecorte = 'processed/' + [System.IO.Path]::GetFileNameWithoutExtension($respuesta.clave) + '.png'
$metadatos = $null
for ($intento = 0; $intento -lt 60; $intento++) {
    $consulta = & aws s3api list-objects-v2 --bucket $Bucket --prefix $claveRecorte --profile $Perfil --region $Region
    if ($LASTEXITCODE -ne 0) {
        throw 'No se pudo consultar el bucket durante la comprobación del recorte.'
    }
    $lista = ($consulta -join "`n") | ConvertFrom-Json
    if (@($lista.Contents | Where-Object { $_.Key -eq $claveRecorte }).Count -gt 0) {
        $consulta = & aws s3api head-object --bucket $Bucket --key $claveRecorte --profile $Perfil --region $Region
        if ($LASTEXITCODE -ne 0) {
            throw 'No se pudieron consultar los metadatos del recorte.'
        }
        $metadatos = ($consulta -join "`n") | ConvertFrom-Json
        break
    }
    Start-Sleep -Seconds 3
}
if ($null -eq $metadatos) {
    throw 'No se encontró el recorte después de esperar tres minutos.'
}
if ($metadatos.ContentType -ne 'image/png' -or $metadatos.ServerSideEncryption -ne 'AES256') {
    throw 'El recorte no tiene el formato PNG o el cifrado esperado.'
}

& aws s3api get-object --bucket $Bucket --key $claveRecorte --profile $Perfil --region $Region $RutaRecorte | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'No se pudo descargar la imagen procesada.'
}
$contenido = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $RutaRecorte).Path)
$firma = [Convert]::ToBase64String($contenido[0..7])
$ancho = [BitConverter]::ToUInt32([byte[]]($contenido[19..16]), 0)
$alto = [BitConverter]::ToUInt32([byte[]]($contenido[23..20]), 0)
if ($firma -ne 'iVBORw0KGgo=' -or $ancho -ne 40 -or $alto -ne 40) {
    throw 'El archivo descargado no es un PNG de 40 por 40 píxeles.'
}

[pscustomobject]@{
    Original = $respuesta.clave
    Recorte = $claveRecorte
    Bucket = $Bucket
    Ancho = $ancho
    Alto = $alto
    Cifrado = $metadatos.ServerSideEncryption
    Archivo = (Resolve-Path -LiteralPath $RutaRecorte).Path
}
