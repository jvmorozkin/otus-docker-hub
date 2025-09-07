param(
    [string]$BaseUrl = "http://arch.homework",
    [int]$Requests = 100
)

function Write-Colored {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-Endpoint {
    param([string]$Url, [string]$Method = "GET", [string]$Body = $null)

    try {
        $headers = @{
            "Content-Type" = "application/json"
        }

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        $requestParams = @{
            Uri = $Url
            Method = $Method
            Headers = $headers
            ErrorAction = 'Stop'
        }

        if ($Body) {
            $requestParams.Body = $Body
        }

        $response = Invoke-WebRequest @requestParams
        $stopwatch.Stop()

        return @{
            Success = $true
            StatusCode = $response.StatusCode
            ResponseTime = $stopwatch.ElapsedMilliseconds
            Content = $response.Content
        }
    }
    catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.Value__ } else { 0 }
        return @{
            Success = $false
            StatusCode = $statusCode
            Error = $_.Exception.Message
        }
    }
}

function Test-All-Endpoints {
    param($Url, $Count)

    $results = @()
    $endpoints = @(
        @{Url = "/health"; Method = "GET"},
        @{Url = "/api/v1/user/1"; Method = "GET"},
        @{Url = "/api/v1/user"; Method = "POST"; Body = '{"username":"testuser","firstName":"Test","lastName":"User","email":"test@example.com","phone":"+79160000000"}'},
        @{Url = "/actuator/prometheus"; Method = "GET"}
    )

    for ($i = 1; $i -le $Count; $i++) {
        foreach ($endpoint in $endpoints) {
            $fullUrl = $Url + $endpoint.Url
            $result = Test-Endpoint -Url $fullUrl -Method $endpoint.Method -Body $endpoint.Body
            $results += [PSCustomObject]@{
                Endpoint = $endpoint.Url
                Method = $endpoint.Method
                Success = $result.Success
                StatusCode = if ($result.Success) { $result.StatusCode } else { "ERROR" }
                ResponseTime = if ($result.Success) { "$($result.ResponseTime)ms" } else { "N/A" }
            }

            # Small pause between requests
            Start-Sleep -Milliseconds 100
        }
    }

    return $results
}

function Show-Results {
    param($Results)

    $grouped = $Results | Group-Object Endpoint, Method

    Write-Colored "`n=== TEST RESULTS ===" "Green"
    foreach ($group in $grouped) {
        $successCount = ($group.Group | Where-Object Success).Count
        $totalCount = $group.Group.Count
        $successRate = [math]::Round(($successCount / $totalCount) * 100, 2)

        $color = if ($successRate -eq 100) { "Green" } elseif ($successRate -ge 80) { "Yellow" } else { "Red" }

        Write-Colored "$($group.Name): $successCount/$totalCount ($successRate%)" $color
    }
}

# Run quick test
$results = Test-All-Endpoints -Url $BaseUrl -Count $Requests
Show-Results -Results $results