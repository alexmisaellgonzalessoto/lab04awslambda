param(
    [ValidateRange(0, 100)][int]$DireccionesNuevas = 2,
    [string]$Perfil = 'lab04awslambda',
    [string]$Region = 'us-east-1'
)

$ErrorActionPreference = 'Stop'
$consulta = & aws service-quotas get-service-quota --service-code ec2 --quota-code L-0263D0A3 --profile $Perfil --region $Region --output json
if ($LASTEXITCODE -ne 0) {
    throw 'No se pudo consultar la cuota aplicada de direcciones IP elásticas.'
}
$limite = (($consulta -join "`n") | ConvertFrom-Json).Quota.Value
$consulta = & aws ec2 describe-addresses --profile $Perfil --region $Region --output json
if ($LASTEXITCODE -ne 0) {
    throw 'No se pudieron consultar las direcciones IP elásticas asignadas.'
}
$direcciones = (($consulta -join "`n") | ConvertFrom-Json).Addresses
$asignadas = @($direcciones | Where-Object { $null -ne $_ }).Count
if ($asignadas + $DireccionesNuevas -gt $limite) {
    throw "La cuota permite $limite direcciones y ya hay $asignadas asignadas. Se necesitan $DireccionesNuevas adicionales antes del despliegue."
}

[pscustomobject]@{
    Region = $Region
    LimiteAplicado = $limite
    DireccionesAsignadas = $asignadas
    DireccionesNuevas = $DireccionesNuevas
    CapacidadSuficiente = $true
}
