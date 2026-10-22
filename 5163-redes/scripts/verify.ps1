param([string]$Region="us-east-1", [string]$Prefix="n1-rsn", [switch]$SkipWaf)
$ErrorActionPreference='Stop'
function Get-Output([string]$Stack,[string]$Key) {
 $v=aws cloudformation describe-stacks --region $Region --stack-name $Stack --query "Stacks[0].Outputs[?OutputKey=='$Key'].OutputValue | [0]" --output text
 if ($LASTEXITCODE -ne 0 -or -not $v -or $v -eq 'None') {throw "No se pudo leer $Key de $Stack"}; return $v.Trim()
}
$bucket=Get-Output "$Prefix-core" 'BucketName'
$alb=Get-Output "$Prefix-core" 'AlbDns'
$cf=Get-Output "$Prefix-edge" 'CloudFrontDomain'
Write-Host 'Pruebas HTTP: registrar salidas, no confundir 403 de WAF con 403 de S3.' -ForegroundColor Cyan
foreach ($entry in @(@('CloudFront D02',"https://$cf/index.html"), @('ALB health',"http://$alb/health"))) {
  $code=curl.exe --max-time 25 -s -o NUL -w '%{http_code}' $entry[1]
  Write-Host "$($entry[0]): HTTP $code"
}
if(-not $SkipWaf) {
  $code=curl.exe --max-time 25 -s -o NUL -w '%{http_code}' "https://$cf/bloqueado"
  Write-Host "WAF ruta /bloqueado: HTTP $code (esperado 418 con WAF activo)"
}
$direct="https://$bucket.s3.$Region.amazonaws.com/D01/informe-interno.txt"
$code=curl.exe --max-time 25 -s -o NUL -w '%{http_code}' $direct
Write-Host "S3 D01 anonimo: HTTP $code (esperado 403)"
Write-Host 'STS identity: '; aws sts get-caller-identity --query '{Account:Account,Arn:Arn}'
Write-Host 'CloudFormation stacks:'; aws cloudformation describe-stacks --region $Region --stack-name "$Prefix-core" --query 'Stacks[0].StackStatus' --output text
Write-Host 'Logs EC2 (si LabRole permite S3 PutObject desde el endpoint):'
aws s3 ls "s3://$bucket/evidencias/" --region $Region
Write-Host 'GUI: revisar VPC, EC2, Target groups, S3, EFS, CloudFront, WAF, CloudFormation y IAM role.'
