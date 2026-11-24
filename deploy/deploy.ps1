<#
.SYNOPSIS
    Build and deploy the Streamlit sentiment analysis app to AWS App Runner.

.DESCRIPTION
    Uses the AWS CLI to create (or reuse) an ECR repository, IAM roles and a
    CodeBuild project that builds the Docker image from the public GitHub repo,
    then creates/updates an App Runner service. No local Docker required.

.EXAMPLE
    .\deploy\deploy.ps1 -Region ap-southeast-2
#>
param(
    [string] $Region = "ap-southeast-2",
    [string] $RepositoryName = "sentiment-analysis",
    [string] $ServiceName = "sentiment-analysis",
    [string] $CodeBuildProject = "sentiment-analysis-build",
    [string] $GitHubUrl = "https://github.com/nguyenvandinh01/SentimentAnalysis.git",
    [string] $Branch = "main",
    [int] $WaitSeconds = 900
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PolicyDir = Join-Path $ScriptDir "policies"

function Invoke-Aws {
    param([string[]] $Arguments, [string] $ErrorMessage)
    $output = & aws @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host $output
        throw $ErrorMessage
    }
    return $output
}

function FileUri {
    param([string] $Path)
    return "file://" + ($Path -replace '\\', '/')
}

function Ensure-Role {
    param([string] $RoleName, [string] $TrustFile, [string] $PolicyFile, [string] $PolicyName)

    $existing = & aws iam get-role --role-name $RoleName 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Creating IAM role: $RoleName"
        Invoke-Aws @("iam", "create-role", "--role-name", $RoleName,
            "--assume-role-policy-document", (FileUri $TrustFile),
            "--description", "Role used by $RoleName for sentiment-analysis deployment") `
            "Failed to create role $RoleName"
        Start-Sleep -Seconds 10
    } else {
        Write-Host "Reusing IAM role: $RoleName"
    }

    Invoke-Aws @("iam", "put-role-policy", "--role-name", $RoleName,
        "--policy-name", $PolicyName, "--policy-document", (FileUri $PolicyFile)) `
        "Failed to attach policy to $RoleName"
    return (Invoke-Aws @("iam", "get-role", "--role-name", $RoleName,
        "--query", "Role.Arn", "--output", "text") "Failed to read role ARN").Trim()
}

Write-Host "==> Checking AWS identity"
$AccountId = (Invoke-Aws @("sts", "get-caller-identity", "--query", "Account", "--output", "text") `
    "AWS CLI is not configured. Run 'aws configure' first.").Trim()
$Registry = "$AccountId.dkr.ecr.$Region.amazonaws.com"
$ImageUri = "$Registry/$RepositoryName`:latest"
Write-Host "Account: $AccountId | Region: $Region | Image: $ImageUri"

Write-Host "==> 1/5 Ensuring ECR repository"
$repo = & aws ecr describe-repositories --repository-names $RepositoryName --region $Region 2>$null
if ($LASTEXITCODE -ne 0) {
    Invoke-Aws @("ecr", "create-repository", "--repository-name", $RepositoryName,
        "--region", $Region, "--image-scanning-configuration", "scanOnPush=true") `
        "Failed to create ECR repository"
    Write-Host "Created ECR repository: $RepositoryName"
} else {
    Write-Host "ECR repository already exists: $RepositoryName"
}

Write-Host "==> 2/5 Ensuring IAM roles"
$CodeBuildRoleArn = Ensure-Role "sentiment-analysis-codebuild-role" `
    (Join-Path $PolicyDir "codebuild-trust-policy.json") `
    (Join-Path $PolicyDir "codebuild-policy.json") `
    "CodeBuildEcrAccess"
$AppRunnerRoleArn = Ensure-Role "sentiment-analysis-apprunner-access-role" `
    (Join-Path $PolicyDir "apprunner-access-trust-policy.json") `
    (Join-Path $PolicyDir "apprunner-access-policy.json") `
    "AppRunnerEcrAccess"
Write-Host "CodeBuild role: $CodeBuildRoleArn"
Write-Host "App Runner role: $AppRunnerRoleArn"

Write-Host "==> 3/5 Creating/updating CodeBuild project"
$envJson = @"
[{"name":"ECR_REPOSITORY","value":"$RepositoryName","type":"PLAINTEXT"}]
"@
$project = & aws codebuild batch-get-projects --names $CodeBuildProject --region $Region 2>$null
$projectExists = ($LASTEXITCODE -eq 0) -and ((($project | ConvertFrom-Json).projects | Measure-Object).Count -gt 0)
$commonArgs = @(
    "--source", "type=GITHUB,location=$GitHubUrl,buildspec=buildspec.yml",
    "--source-version", "refs/heads/$Branch",
    "--artifacts", "type=NO_ARTIFACTS",
    "--environment", "type=LINUX_CONTAINER,image=aws/codebuild/standard:7.0,computeType=BUILD_GENERAL1_SMALL,privilegedMode=true",
    "--environment-variables", $envJson,
    "--region", $Region
)
if ($projectExists) {
    Invoke-Aws (@("codebuild", "update-project", "--name", $CodeBuildProject) + $commonArgs) `
        "Failed to update CodeBuild project"
    Write-Host "Updated CodeBuild project: $CodeBuildProject"
} else {
    Start-Sleep -Seconds 5
    Invoke-Aws (@("codebuild", "create-project", "--name", $CodeBuildProject,
        "--service-role", $CodeBuildRoleArn,
        "--description", "Build and push the sentiment-analysis Docker image to ECR") + $commonArgs) `
        "Failed to create CodeBuild project"
    Write-Host "Created CodeBuild project: $CodeBuildProject"
}

Write-Host "==> 4/5 Building and pushing Docker image"
$buildId = (Invoke-Aws @("codebuild", "start-build", "--project-name", $CodeBuildProject,
    "--region", $Region, "--query", "build.id", "--output", "text") `
    "Failed to start CodeBuild build").Trim()
Write-Host "CodeBuild build ID: $buildId"

$deadline = (Get-Date).AddSeconds($WaitSeconds)
$status = "IN_PROGRESS"
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 15
    $details = Invoke-Aws @("codebuild", "batch-get-builds", "--ids", $buildId,
        "--region", $Region) "Failed to get build status"
    $build = ($details | ConvertFrom-Json).builds[0]
    if ($build.buildStatus -ne $status) {
        $status = $build.buildStatus
        Write-Host "Build status: $status"
    }
    if ($status -in @("SUCCEEDED", "FAILED", "FAULT", "STOPPED", "TIMED_OUT")) { break }
}
if ($status -ne "SUCCEEDED") {
    Write-Host "Build log: $($build.logs.deepLink)"
    throw "Docker image build failed with status: $status"
}

Write-Host "==> 5/5 Creating/updating App Runner service"
$sourceConfig = @"
{
  "ImageRepository": {
    "ImageRepositoryType": "ECR",
    "ImageIdentifier": "$ImageUri",
    "ImageConfiguration": {
      "Port": "8080",
      "RuntimeEnvironmentVariables": {
        "NLTK_DATA": "/app/nltk_data"
      }
    }
  },
  "AutoDeploymentsEnabled": true,
  "AuthenticationConfiguration": {
    "AccessRoleArn": "$AppRunnerRoleArn"
  }
}
"@
$instanceConfig = '{"Cpu":"1","Memory":"2Gb"}'
$healthConfig = '{"Protocol":"HTTP","Path":"/_stcore/health","IntervalSeconds":20,"TimeoutSeconds":10,"HealthyThreshold":2,"UnhealthyThreshold":3}'

$serviceArn = (Invoke-Aws @("apprunner", "list-services", "--region", $Region,
    "--query", "ServiceSummaries[?ServiceName=='$ServiceName'].ServiceArn", "--output", "text") `
    "Failed to list App Runner services").Trim()

if ([string]::IsNullOrWhiteSpace($serviceArn)) {
    $serviceArn = (Invoke-Aws @("apprunner", "create-service", "--service-name", $ServiceName,
        "--source-configuration", $sourceConfig,
        "--instance-configuration", $instanceConfig,
        "--health-check-configuration", $healthConfig,
        "--region", $Region,
        "--query", "Service.ServiceArn", "--output", "text") `
        "Failed to create App Runner service").Trim()
    Write-Host "Created App Runner service: $serviceArn"
} else {
    Invoke-Aws @("apprunner", "update-service", "--service-arn", $serviceArn,
        "--source-configuration", $sourceConfig,
        "--instance-configuration", $instanceConfig,
        "--health-check-configuration", $healthConfig,
        "--region", $Region) "Failed to update App Runner service" | Out-Null
    Write-Host "Updated App Runner service: $serviceArn"
}

$deadline = (Get-Date).AddSeconds($WaitSeconds)
$svcStatus = "OPERATION_IN_PROGRESS"
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 20
    $svc = Invoke-Aws @("apprunner", "describe-service", "--service-arn", $serviceArn,
        "--region", $Region) "Failed to describe App Runner service"
    $svcObj = $svc | ConvertFrom-Json
    if ($svcObj.Service.Status -ne $svcStatus) {
        $svcStatus = $svcObj.Service.Status
        Write-Host "Service status: $svcStatus"
    }
    if ($svcStatus -in @("RUNNING", "CREATE_FAILED", "UPDATE_FAILED", "DELETED")) { break }
}

Write-Host ""
Write-Host "================ DEPLOYMENT SUMMARY ================"
Write-Host "Service ARN : $serviceArn"
Write-Host "Status      : $svcStatus"
if ($svcObj.Service.ServiceUrl) {
    Write-Host "URL         : https://$($svcObj.Service.ServiceUrl)"
}
Write-Host "===================================================="

if ($svcStatus -ne "RUNNING") {
    throw "App Runner service is not running (status: $svcStatus)"
}
