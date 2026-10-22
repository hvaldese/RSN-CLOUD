param(
  [string]$Region = "us-east-1",
  [string]$Prefix = "n1-rsn",
  [string]$InstanceProfile = "LabInstanceProfile",
  [switch]$SkipWaf,
  [switch]$NoSsmEndpoints
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
function Assert-LastExit($label) {
  if ($LASTEXITCODE -ne 0) { throw "$label ha fallado (codigo $LASTEXITCODE). Revisar eventos CloudFormation y permisos Learner Lab." }
}
function Get-Output([string]$Stack, [string]$Key, [string]$RegionForQuery) {
  $value = aws cloudformation describe-stacks --stack-name $Stack --region $RegionForQuery --query "Stacks[0].Outputs[?OutputKey=='$Key'].OutputValue | [0]" --output text
  Assert-LastExit "Leer output $Key de $Stack"
  if (-not $value -or $value -eq 'None') { throw "No existe output: $Stack/$Key" }
  return $value.Trim()
}
aws --version; Assert-LastExit 'AWS CLI'
$identity = aws sts get-caller-identity --query 'Account' --output text
Assert-LastExit 'STS'
Write-Host "AWS account: $identity; Region: $Region; Prefix: $Prefix" -ForegroundColor Yellow
Write-Host 'PRECAUCION: se crearan ALB, EC2, EFS, endpoints y posiblemente WAF/CloudFront con costes.'
if ((Read-Host "Escribe DESPLEGAR para continuar") -cne 'DESPLEGAR') { throw 'Cancelado' }
$core = "$Prefix-core"; $edge = "$Prefix-edge"; $waf = "$Prefix-waf"
$ssm = if($NoSsmEndpoints) {'false'} else {'true'}
Write-Host 'VALIDACION SINTACTICA AWS (no verifica cuotas ni permisos)' -ForegroundColor Cyan
$templatesToValidate = @('core.yaml','edge.yaml')
if (-not $SkipWaf) { $templatesToValidate += 'waf-global.yaml' }
foreach ($tpl in $templatesToValidate) {
  $validationRegion = if ($tpl -eq 'waf-global.yaml') { 'us-east-1' } else { $Region }
  aws cloudformation validate-template --region $validationRegion --template-body "file://$root/infra/$tpl" | Out-Null
  Assert-LastExit "Validacion $tpl"
}
Write-Host '01 / 03 - Stack principal (regional)' -ForegroundColor Cyan
aws cloudformation deploy --region $Region --template-file "$root/infra/core.yaml" --stack-name $core --no-fail-on-empty-changeset --parameter-overrides "ProjectPrefix=$Prefix" "InstanceProfileName=$InstanceProfile" "EnableSsmEndpoints=$ssm" --tags "Project=$Prefix" "Course=RSN-N1"
Assert-LastExit "Despliegue core $core"
$bucket = Get-Output $core 'BucketName' $Region
$endpoint = Get-Output $core 'CorpS3EndpointId' $Region
Write-Host "02 / 03 - Carga inicial en s3://$bucket" -ForegroundColor Cyan
aws s3 cp "$root/data/D01/informe-interno.txt" "s3://$bucket/D01/informe-interno.txt" --region $Region
Assert-LastExit 'Carga D01'
aws s3 cp "$root/data/D03/inventario-interno.txt" "s3://$bucket/D03/inventario-interno.txt" --region $Region
Assert-LastExit 'Carga D03'
aws s3 cp "$root/data/D02/index.html" "s3://$bucket/D02/index.html" --region $Region --content-type 'text/html; charset=utf-8'
Assert-LastExit 'Carga D02'
$wafArn = ''
if (-not $SkipWaf) {
  Write-Host 'WAF global: crear en us-east-1; si falla, revisar permisos y reintentar con -SkipWaf.' -ForegroundColor Cyan
  aws cloudformation deploy --region us-east-1 --template-file "$root/infra/waf-global.yaml" --stack-name $waf --no-fail-on-empty-changeset --parameter-overrides "ProjectPrefix=$Prefix" --tags "Project=$Prefix" "Course=RSN-N1"
  Assert-LastExit "Despliegue WAF $waf"
  $wafArn = Get-Output $waf 'WafArn' 'us-east-1'
}
Write-Host '03 / 03 - CloudFront OAC + politica bucket (global, stack regional)' -ForegroundColor Cyan
aws cloudformation deploy --region $Region --template-file "$root/infra/edge.yaml" --stack-name $edge --no-fail-on-empty-changeset --parameter-overrides "ProjectPrefix=$Prefix" "BucketName=$bucket" "CorpS3EndpointId=$endpoint" "WafArn=$wafArn" --tags "Project=$Prefix" "Course=RSN-N1"
Assert-LastExit "Despliegue edge $edge"
$domain = Get-Output $edge 'CloudFrontDomain' $Region
$alb = Get-Output $core 'AlbDns' $Region
Write-Host "FINALIZADO. CloudFront: https://$domain | ALB laboratorio: http://$alb" -ForegroundColor Green
Write-Host "Ejecuta: .\scripts\verify.ps1 -Region $Region -Prefix $Prefix $(if($SkipWaf){'-SkipWaf'})"
