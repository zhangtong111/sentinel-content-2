function ConnectAzCloud {
    $RawCreds = $Env:creds | ConvertFrom-Json

    Clear-AzContext -Scope Process;
    Clear-AzContext -Scope CurrentUser -Force -ErrorAction SilentlyContinue;
    
    Add-AzEnvironment `
        -Name $Env:cloudEnv `
        -ActiveDirectoryEndpoint $RawCreds.activeDirectoryEndpointUrl `
        -ResourceManagerEndpoint $RawCreds.resourceManagerEndpointUrl `
        -ActiveDirectoryServiceEndpointResourceId $RawCreds.activeDirectoryServiceEndpointResourceId `
        -GraphEndpoint $RawCreds.graphEndpointUrl | out-null;

    $servicePrincipalKey = ConvertTo-SecureString $RawCreds.clientSecret.replace("'", "''") -AsPlainText -Force
    $psCredential = New-Object System.Management.Automation.PSCredential($RawCreds.clientId, $servicePrincipalKey)

    Connect-AzAccount -ServicePrincipal -Tenant $RawCreds.tenantId -Credential $psCredential -Environment $Env:cloudEnv | out-null;
    Set-AzContext -Tenant $RawCreds.tenantId | out-null;
}

if ($Env:cloudEnv -ne 'AzureCloud') {
    Write-Output "Attempting Sign In to Azure Cloud"
    ConnectAzCloud
}

Write-Output "Starting Deployment for Files in path: $Env:directory"
if (Test-Path -Path $Env:directory) {
    $totalAttempts = 0;
    $totalFailed = 0;
    Get-ChildItem -Path $Env:directory -Recurse -Filter *.json |
    ForEach-Object {
        $CurrentFile = $_.FullName
        Try {
            $totalAttempts ++
            Test-AzResourceGroupDeployment -ResourceGroupName $Env:resourceGroupName -TemplateFile $CurrentFile -logAnalyticsWorkspaceName $Env:workspaceName
            New-AzResourceGroupDeployment -ResourceGroupName $Env:resourceGroupName -TemplateFile $CurrentFile -logAnalyticsWorkspaceName $Env:workspaceName
        }
        Catch {
            $totalFailed++
            Write-Output "[Warning] Failed to deploy $CurrentFile : $_"
        }
    }
    if ($totalAttempts -gt 0 && $totalFailed -gt 0) {
        Throw "$totalFailed of $totalAttempts deployments failed."
    }
}
else {
    Write-Output "[Warning] $Env:directory not found. nothing to deploy"
}
