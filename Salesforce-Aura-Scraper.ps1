<#
.SYNOPSIS
Downloads an installer by scraping a Salesforce Aura API endpoint.

.DESCRIPTION
This script builds a raw Salesforce/Aura API POST request to scrape a vendor help portal for a direct .exe installer link, avoiding manual downloads and authentication prompts.
#>

function Download-NutrikidsInstaller {
    [CmdletBinding()]
    param (
        [string]$ArticleUrl = 'https://help.heartlandschoolsolutions.com/s/article/Install-or-Update-Nutrikids-POS-Serving-Line',
        [string]$DestinationPath = 'C:\Temp'
    )

    $urlName = ($ArticleUrl -split '/')[-1]
    
    if (-not (Test-Path $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath | Out-Null
    }

    $apiEndpoint = 'https://help.heartlandschoolsolutions.com/s/sfsites/aura?r=7&aura.ApexAction.execute=1'

    $requestHeaders = @{
        'Accept'           = '*/*'
        'Accept-Encoding'  = 'gzip, deflate, br, zstd'
        'Content-Type'     = 'application/x-www-form-urlencoded; charset=UTF-8'
        'Origin'           = 'https://help.heartlandschoolsolutions.com'
        'User-Agent'       = 'Mozilla/5.0'
        'X-Requested-With' = 'XMLHttpRequest'
    }

    $messageTemplate = '{{"actions":[{{"id":"210;a","descriptor":"aura://ApexActionController/ACTION$execute","callingDescriptor":"UNKNOWN","params":{{"namespace":"articleBody","classname":"ArticleController","method":"getArticleInfoLightning","params":{{"recordId":"","urlName":"{0}","articleNumber":"","queryBy":"urlName","articleAPIName":"Knowledge_Article__kav","articleBodyAPIName":"Solution__c","articleBodyAPIName2":"Solution__c","initial":false}},"cacheable":true,"isContinuation":false}}}}]}}'

    $requestBody = @{
        'r'                      = '7'
        'aura.ApexAction.execute'= '1'
        'message'                = ($messageTemplate -f $urlName)
        'aura.context'           = '{"mode":"PROD","fwuid":"eE5UbjZPdVlRT3M0d0xtOXc5MzVOQWg5TGxiTHU3MEQ5RnBMM0VzVXc1cmcxMi42MjkxNDU2LjE2Nzc3MjE2","app":"siteforce:communityApp","loaded":{"APPLICATION@markup://siteforce:communityApp":"1305_7pTC6grCTP7M16KdvDQ-Xw"},"dn":[],"globals":{},"uad":true}'
        'aura.pageURI'           = "/s/article/$urlName"
        'aura.token'             = 'null'
    }

    try {
        $response = Invoke-WebRequest -Uri $apiEndpoint -Method POST -Headers $requestHeaders -Body $requestBody -UseBasicParsing -ErrorAction Stop
        $responseText = $response.Content

        if ($responseText -match 'https?://[^\s"]+?\.(exe|msi)') {
            $downloadUrl = $Matches[0]

            if ($downloadUrl -match 'https://www\.google\.com/url\?q=([^&]+)') {
                $downloadUrl = [System.Web.HttpUtility]::UrlDecode($Matches[1])
            }

            $outputFile = Join-Path -Path $DestinationPath -ChildPath "Installer.exe"

            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($downloadUrl, $outputFile)
            $webClient.Dispose()

            Write-Host "Download complete: $outputFile"
            return $outputFile
        }
    }
    catch {
        Write-Error "Download failed: $_"
    }
}
