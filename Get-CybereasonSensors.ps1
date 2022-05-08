Function global:Get-CybereasonSensors {

    <#
.SYNOPSIS
Retrieves all sensors from the Cybereason on-premises API

.DESCRIPTION
Retrieve all of the sensors (agents or clients) from a Cybereason on-premises console API. You must have a session cookie! Returns a PSCustomObject with the results which you will need to parse further.

.PARAMETER server_fqdn
Required string - This is the fully qualified domain name of the Cybereason console. There is no error-checking on this. Make sure you have it correct.

.PARAMETER session_id
Required String - This is the 32-character string (session id) that you received when you authenticated to the console (See Get-CybereasonCookie)

.PARAMETER limit
Optional Integer for the request body. The value must be between 0 and 1000. The default when not specified is 1000

.PARAMETER offset
Optional Integer for the request body. The value must be 0 or greater. This represents the current "page" of results. The default when not specified is 0 (first page)

.PARAMETER DebugMode
Optional Switch that will verbosely display the parameters that are sent to Invoke-WebRequest (good for troubleshooting)

.EXAMPLE
Get-CybereasonSensors -server_fqdn server.domain.com -session_id 53A09D960B8D553AEFDD73C1B4F55087

.LINK
https://github.com/Cybereason-Fan/Get-CybereasonSensors
#>

    Param(
        [OutputType([PSCustomObject])]
        [Parameter(Mandatory = $true)]
        [string]$session_id,
        [Parameter(Mandatory = $true)]
        [string]$server_fqdn,
        [Parameter(Mandatory = $false)]
        [string]$limit,
        [Parameter(Mandatory = $false)]
        [string]$offset,
        [Parameter(Mandatory = $false)]
        [switch]$DebugMode
    )
    [int32]$ps_version_major = $PSVersionTable.PSVersion.Major
    If ( $null -eq (Get-Module -Name Microsoft.PowerShell.Utility) ) {
        Import-Module Microsoft.Powershell.Utility
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    [string]$regex_jsessionid = '^[0-9A-F]{32}$'
    [string]$api_url = "https://$server_fqdn/rest/"
    [string]$api_command = 'sensors/query'
    [string]$command_url = ($api_url + $api_command)
    [string]$server_name = $server_fqdn -replace 'http[s]{0,}://'
    If ( $limit -eq '') {
        [int]$limit = 1000
    }
    ElseIf ( $limit -notmatch '^-?\d+$') {
        Write-Host "Error: Limit must be an integer between 0-1000"
        Return
    }
    ElseIf (([int]$limit -lt 0) -or ([int]$limit -gt 1000)) {
        Write-Host "Error: Limit must be between 0-1000"
        Return
    }
    If ( $offset -eq '') {
        [int]$offset = 0
    }
    ElseIf ( $offset -notmatch '^-?\d+$') {
        Write-Host "Error: Offset must be an integer of 0 or greater"
        Return
    }
    ElseIf ([int]$offset -lt 0) {
        Write-Host "Error: Offset must be greater than or equal to 0"
        Return
    }
    If ( $session_id -cnotmatch $regex_jsessionid ) {
        Write-Host "Error: The session id must be a case-sensitive 32 character long string of 0-9 and A-F."
        Return
    }
    $Error.Clear()
    Try {
        [Microsoft.PowerShell.Commands.WebRequestSession]$web_session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    }
    Catch {
        [array]$error_clone = $Error.Clone()
        [string]$error_message = $error_clone | Where-Object { $null -ne $_.Exception } | Select-Object -First 1 | Select-Object -ExpandProperty Exception
        Write-Host "Error: New-Object failed to create a web request session object due to [$error_message]"
        Return
    }
    $Error.Clear()
    Try {
        [System.Net.Cookie]$cookie = New-Object System.Net.Cookie
        $cookie.Name = 'JSESSIONID'
        $cookie.Value = $session_id
        $cookie.Domain = $server_name
    }
    Catch {
        [array]$error_clone = $Error.Clone()
        [string]$error_message = $error_clone | Where-Object { $null -ne $_.Exception } | Select-Object -First 1 | Select-Object -ExpandProperty Exception
        Write-Host "Error: New-Object failed to create a cookie object due to [$error_message]"
        Return
    }
    $Error.Clear()
    Try {
        $web_session.Cookies.Add($cookie)
    }
    Catch {
        [array]$error_clone = $Error.Clone()
        [string]$error_message = $error_clone | Where-Object { $null -ne $_.Exception } | Select-Object -First 1 | Select-Object -ExpandProperty Exception
        Write-Host "Error: Failed to add the cookie object to the web request session object due to [$error_message]"
        Return
    }
    [hashtable]$request_body = @{}
    $request_body.Add('limit', [string]$limit)
    $request_body.Add('offset', [string]$offset)
    [string]$request_body_json = $request_body | ConvertTo-Json -Compress
    [hashtable]$parameters = @{}
    $parameters.Add('Uri', $command_url)
    $parameters.Add('Body', $request_body_json)
    $parameters.Add('Method', 'POST')
    $parameters.Add('ContentType', 'application/json')
    $parameters.Add('WebSession', $web_session)
    If ( $DebugMode -eq $true) {
        [string]$parameters_display = $parameters | ConvertTo-Json -Compress
        Write-Host "Debug: Sending parameters to Invoke-WebRequest $parameters_display"
    }
    $ProgressPreference = 'SilentlyContinue'
    $Error.Clear()
    Try {
        If ( $ps_version_major -eq 5 ) {
            [Microsoft.PowerShell.Commands.HtmlWebResponseObject]$response = Invoke-WebRequest @parameters
        }
        ElseIf ( $ps_version_major -ge 7 ) {
            [Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject]$response = Invoke-WebRequest @parameters
        }
        Else {
            Write-host "Error: The version of PowerShell could not be determined"
            Return
        }  
    }
    Catch {
        [array]$error_clone = $Error.Clone()
        [string]$error_message = $error_clone | Where-Object { $null -ne $_.Exception } | Select-Object -First 1 | Select-Object -ExpandProperty Exception
        Write-Host "Error: Invoke-WebRequest failed due to [$error_message]"
        Return
    }
    If ( $response.StatusCode -isnot [int]) {
        Write-Host "Error: Somehow there was no numerical response code"
        Return
    }
    [int]$response_statuscode = $response.StatusCode
    If ( $response_statuscode -ne 200) {
        Write-Host "Error: Received numerical status code [$response_statuscode] instead of 200 'OK'. Please look into this."
        Return
    }
    $Error.Clear()
    Try {    
        [PSCustomObject]$response_content = $response.Content | ConvertFrom-Json
    }
    Catch {
        [array]$error_clone = $Error.Clone()
        [string]$error_message = $error_clone | Where-Object { $null -ne $_.Exception } | Select-Object -First 1 | Select-Object -ExpandProperty Exception
        Write-Host "Error: ConvertFrom-Json failed due to [$error_message] [$response]"
        Return
    }
    Return $response_content
}