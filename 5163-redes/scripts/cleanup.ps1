param([string]$Region="us-east-1",[string]$Prefix="n1-rsn",[switch]$SkipWaf)
$ErrorActionPreference = 'Stop'
$account=aws sts get-caller-identity --query Account --output text
if($LASTEXITCODE -ne 0) { throw 'No hay credenciales AWS validas' }
Write-Host "BORRADO TOTAL DE LA PRACTICA $Prefix en cuenta $account ($Region). Incluye objetos y evidencias." -ForegroundColor Red
if((Read-Host 'Para confirmar escribe BORRAR-N1') -cne 'BORRAR-N1'){throw 'Cancelado'}
$core="$Prefix-core";$edge="$Prefix-edge";$waf="$Prefix-waf"
$bucket=aws cloudformation describe-stacks --stack-name $core --region $Region --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue | [0]" --output text
if($LASTEXITCODE -ne 0 -or -not $bucket -or $bucket -eq 'None') {throw 'No se encontro el bucket. Comprobar las pilas manualmente.'}
Write-Host '1/4 Borrar CloudFront, OAC y politica S3. Puede tardar.'
aws cloudformation delete-stack --stack-name $edge --region $Region
if($LASTEXITCODE -ne 0){throw 'Error al pedir eliminacion edge'}
aws cloudformation wait stack-delete-complete --stack-name $edge --region $Region
if($LASTEXITCODE -ne 0){throw 'Edge no se pudo eliminar. Revisar eventos.'}
if(-not $SkipWaf) {
  Write-Host '2/4 Borrar WAF global'
  aws cloudformation delete-stack --stack-name $waf --region us-east-1
  if($LASTEXITCODE -ne 0){throw 'No se pudo solicitar eliminar WAF'}
  aws cloudformation wait stack-delete-complete --stack-name $waf --region us-east-1
  if($LASTEXITCODE -ne 0){throw 'No se pudo eliminar WAF'}
}
Write-Host '3/4 Borrar objetos del bucket'
aws s3 rm "s3://$bucket" --recursive --region $Region
if($LASTEXITCODE -ne 0){throw 'No se pudieron eliminar todos los objetos'}
Write-Host '4/4 Borrar infraestructura base (bucket tiene Retain, se borra despues)'
aws cloudformation delete-stack --stack-name $core --region $Region
if($LASTEXITCODE -ne 0){throw 'Error al solicitar eliminar core'}
aws cloudformation wait stack-delete-complete --stack-name $core --region $Region
if($LASTEXITCODE -ne 0){throw 'Core no se pudo eliminar: revisar eventos.'}
aws s3 rb "s3://$bucket" --region $Region
if($LASTEXITCODE -ne 0){Write-Warning 'Bucket retenido: revisar y borrar manualmente.'}
Write-Host 'Revisar consola: WAF, CloudFront, ALB, EC2, EFS, VPC endpoints y S3.' -ForegroundColor Green
