param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$Url
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http

$script:PruebasEjecutadas = 0
$script:Aprobadas = 0
$script:Fallidas = 0
$aAcentuada = [char]0x00E1
$uAcentuada = [char]0x00FA

function Invoke-SolicitudHttp {
  param(
    [Parameter(Mandatory = $true)]
    [System.Net.Http.HttpClient]$Cliente,
    [Parameter(Mandatory = $true)]
    [string]$Metodo,
    [Parameter(Mandatory = $true)]
    [string]$Direccion,
    [AllowNull()]
    [string]$Cuerpo,
    [hashtable]$Cabeceras = @{}
  )

  $metodoHttp = [System.Net.Http.HttpMethod]::new($Metodo)
  $solicitud = [System.Net.Http.HttpRequestMessage]::new($metodoHttp, $Direccion)
  $respuesta = $null

  try {
    if ($null -ne $Cuerpo) {
      $solicitud.Content = [System.Net.Http.StringContent]::new($Cuerpo, [System.Text.Encoding]::UTF8, 'application/json')
    }

    foreach ($cabecera in $Cabeceras.GetEnumerator()) {
      [void]$solicitud.Headers.TryAddWithoutValidation([string]$cabecera.Key, [string]$cabecera.Value)
    }

    $respuesta = $Cliente.SendAsync($solicitud).GetAwaiter().GetResult()
    $contenido = $respuesta.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    $cabecerasRespuesta = @{}

    foreach ($cabecera in $respuesta.Headers) {
      $cabecerasRespuesta[$cabecera.Key.ToLowerInvariant()] = [string]::Join(', ', [string[]]$cabecera.Value)
    }

    foreach ($cabecera in $respuesta.Content.Headers) {
      $cabecerasRespuesta[$cabecera.Key.ToLowerInvariant()] = [string]::Join(', ', [string[]]$cabecera.Value)
    }

    [pscustomobject]@{
      StatusCode = [int]$respuesta.StatusCode
      Cuerpo = $contenido
      Cabeceras = $cabecerasRespuesta
    }
  }
  finally {
    if ($null -ne $respuesta) {
      $respuesta.Dispose()
    }
    $solicitud.Dispose()
  }
}

function Get-MensajeRespuesta {
  param(
    [AllowEmptyString()]
    [string]$Cuerpo
  )

  try {
    $contenido = $Cuerpo | ConvertFrom-Json -ErrorAction Stop
    if ($null -ne $contenido.mensaje) {
      return [string]$contenido.mensaje
    }
  }
  catch {
  }

  return $null
}

function Test-ValorCabecera {
  param(
    [AllowNull()]
    [string]$Valor,
    [Parameter(Mandatory = $true)]
    [string]$Esperado
  )

  if ($null -eq $Valor) {
    return $false
  }

  return @($Valor -split ',' | ForEach-Object { $_.Trim() }) -icontains $Esperado
}

function Register-Resultado {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Nombre,
    [Parameter(Mandatory = $true)]
    [bool]$Aprobada,
    [Parameter(Mandatory = $true)]
    [string]$Esperado,
    [Parameter(Mandatory = $true)]
    [string]$Obtenido
  )

  $script:PruebasEjecutadas++
  if ($Aprobada) {
    $script:Aprobadas++
    $estado = 'APROBADA'
    $color = 'Green'
  }
  else {
    $script:Fallidas++
    $estado = 'FALLIDA'
    $color = 'Red'
  }

  Write-Host ''
  Write-Host $Nombre
  Write-Host "Esperado: $Esperado"
  Write-Host "Obtenido: $Obtenido"
  Write-Host $estado -ForegroundColor $color
}

$cliente = [System.Net.Http.HttpClient]::new()
$cliente.Timeout = [TimeSpan]::FromSeconds(30)

try {
  try {
    $mensajeEsperado = "El cuerpo debe contener JSON v${aAcentuada}lido."
    $respuesta = Invoke-SolicitudHttp -Cliente $cliente -Metodo 'POST' -Direccion $Url -Cuerpo '{"imagen_base64":'
    $mensaje = Get-MensajeRespuesta -Cuerpo $respuesta.Cuerpo
    $correcta = $respuesta.StatusCode -eq 400 -and $mensaje -ceq $mensajeEsperado
    Register-Resultado -Nombre "PRUEBA 1: JSON inv${aAcentuada}lido" -Aprobada $correcta -Esperado "HTTP 400; mensaje: $mensajeEsperado" -Obtenido "HTTP $($respuesta.StatusCode); mensaje: $mensaje"
  }
  catch {
    Register-Resultado -Nombre "PRUEBA 1: JSON inv${aAcentuada}lido" -Aprobada $false -Esperado "HTTP 400 y el mensaje de JSON inv${aAcentuada}lido" -Obtenido "Error al realizar la solicitud: $($_.Exception.Message)"
  }

  try {
    $mensajeEsperado = 'Los formatos permitidos son PNG, JPEG, GIF y WebP.'
    $cuerpo = '{"imagen_base64":"AA==","tipo_contenido":"application/pdf"}'
    $respuesta = Invoke-SolicitudHttp -Cliente $cliente -Metodo 'POST' -Direccion $Url -Cuerpo $cuerpo
    $mensaje = Get-MensajeRespuesta -Cuerpo $respuesta.Cuerpo
    $correcta = $respuesta.StatusCode -eq 415 -and $mensaje -ceq $mensajeEsperado
    Register-Resultado -Nombre 'PRUEBA 2: formato no admitido' -Aprobada $correcta -Esperado "HTTP 415; mensaje: $mensajeEsperado" -Obtenido "HTTP $($respuesta.StatusCode); mensaje: $mensaje"
  }
  catch {
    Register-Resultado -Nombre 'PRUEBA 2: formato no admitido' -Aprobada $false -Esperado 'HTTP 415 y el mensaje de formatos permitidos' -Obtenido "Error al realizar la solicitud: $($_.Exception.Message)"
  }

  try {
    $cabeceras = @{
      Origin = 'https://ejemplo.com'
      'Access-Control-Request-Method' = 'POST'
      'Access-Control-Request-Headers' = 'content-type'
    }
    $respuesta = Invoke-SolicitudHttp -Cliente $cliente -Metodo 'OPTIONS' -Direccion $Url -Cuerpo $null -Cabeceras $cabeceras
    $origen = $respuesta.Cabeceras['access-control-allow-origin']
    $metodos = $respuesta.Cabeceras['access-control-allow-methods']
    $cabecerasPermitidas = $respuesta.Cabeceras['access-control-allow-headers']
    $maxAge = $respuesta.Cabeceras['access-control-max-age']
    $estadoCorrecto = $respuesta.StatusCode -ge 200 -and $respuesta.StatusCode -lt 300
    $correcta = $estadoCorrecto -and $origen -eq '*' -and (Test-ValorCabecera -Valor $metodos -Esperado 'POST') -and (Test-ValorCabecera -Valor $cabecerasPermitidas -Esperado 'content-type') -and $maxAge -eq '300'
    $esperado = 'HTTP 2xx; Allow-Origin: *; Allow-Methods incluye POST; Allow-Headers incluye content-type; Max-Age: 300'
    $obtenido = "HTTP $($respuesta.StatusCode); Allow-Origin: $origen; Allow-Methods: $metodos; Allow-Headers: $cabecerasPermitidas; Max-Age: $maxAge"
    Register-Resultado -Nombre 'PRUEBA 3: CORS' -Aprobada $correcta -Esperado $esperado -Obtenido $obtenido
  }
  catch {
    Register-Resultado -Nombre 'PRUEBA 3: CORS' -Aprobada $false -Esperado "Preflight correcto seg${uAcentuada}n api_carga.tf" -Obtenido "Error al realizar la solicitud: $($_.Exception.Message)"
  }
}
finally {
  $cliente.Dispose()
}

Write-Host ''
Write-Host 'Resumen'
Write-Host "Pruebas ejecutadas: $script:PruebasEjecutadas"
Write-Host "Aprobadas: $script:Aprobadas"
Write-Host "Fallidas: $script:Fallidas"

if ($script:Fallidas -gt 0) {
  exit 1
}

exit 0
