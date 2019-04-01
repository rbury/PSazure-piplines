<#
.Synopsis
    Build script (https://github.com/rbury/{Module_Name})
    -i- Azure Piplines CI -i-
#>

Set-StrictMode -Version Latest

# Set to proper Module Name and desired compliance for pass
$ModuleName = 'Module'
$Compliance = '0'
$script:moduleManifestFile = (".\$ModuleName\$ModuleName.psd1")

if (-not($env:TF_BUILD)) {

    $env:Build_SourcesDirectory = $PSScriptRoot
    $env:Common_TestResultsDirectory = "$PSScriptRoot\TestOutPut"

}

# Synopsis: Run full Pipleline
task . Clean, PreTest, Build, Test, Analyze

# Synopsis: Run tests only
task PreTestOnly PreTest

# Synopsis: Run tests and analyze
task TestAnalyze PreTest, Analyze

# Synopsis: Run full Pipeline with Release
task Release Clean, PreTest, UpdateVersion, Build, Test, Analyze, Archive

#region Clean
task Clean {
    # Lets get this cleaned up!
    if(Test-Path -Path "$env:Build_SourcesDirectory\OutPut") {

        Remove "$env:Build_SourcesDirectory\OutPut"

    }

    New-Item -Path "$evn:Build_SourcesDirectory\Output" -ItemType Directory -Force

}
#endregion

#region Analyze
# Synopsis: Analyze Code with PSScriptAnalyzer
task Analyze {

    $scriptAnalyzerParams = @{

        Path     = "$env:Build_SourcesDirectory/$ModuleName/"
        Severity = @('Error', 'Warning')
        Recurse  = $true
        Verbose  = $false

    }

    $saResults = Invoke-ScriptAnalyzer @scriptAnalyzerParams

    # Save Analyze Results as JSON
    $saResults | ConvertTo-Json | Set-Content "$env:Common_TestResultsDirectory/AnalysisResults.json"

    if ($saResults) {

        $saResults | Format-Table
        throw "One or more PSScriptAnalyzer errors/warnings where found."

    }

}
#endregion

#region PreTest
# Synopsis: Test with Pester, publish results and coverage
task PreTest {

    Import-Module $env:Build_SourcesDirectory/$ModuleName/$ModuleName.psd1

    $invokePesterParams = @{

        OutputFile   = "$env:Common_TestResultsDirectory/TEST-Results-$($ModuleName).xml"
        OutputFormat = 'NUnitXml'
        Strict       = $true
        PassThru     = $true
        Verbose      = $false
        EnableExit   = $false
        CodeCoverage = (Get-ChildItem "$env:Build_SourcesDirectory/$ModuleName" -Recurse -Include '*.psm1', '*.ps1' -Exclude '*.Tests.*').FullName
        Script       = (Get-ChildItem -Path "$env:Build_SourcesDirectory/tests" -Recurse -Include '*.tests.ps1' -Depth 5 -Force)

    }

    # Save Test Results as NUnitXml
    $testResults = Invoke-Pester @invokePesterParams

    $numberFails = $testResults.FailedCount
    assert($numberFails -eq 0) ('Failed "{0}" unit tests.' -f $numberFails)

    # Save Test Results as JSON
    $testresults | ConvertTo-Json | Set-Content "$env:Common_TestResultsDirectory/PesterResults.json"

    # Fail Build if Coverage is under requirement
    $overallCoverage = [Math]::Floor(($testResults.CodeCoverage.NumberOfCommandsExecuted / $testResults.CodeCoverage.NumberOfCommandsAnalyzed) * 100)
    assert($overallCoverage -ge $Compliance) ('Code Coverage: "{0}", build requirement: "{1}"' -f $overallCoverage, $Compliance)

}
#endregion

#region UpdateVersion
task UpdateVersion {

    try {

        $manifestContent = Get-Content $moduleManifestFile -Raw
        #[version]$version = [regex]::matches($manifestContent, "ModuleVersion\s=\s\'(?<version>(\d+\.)?(\d+\.)?(\*|\d+))") | ForEach-Object {$_.groups['version'].value}
        #$newVersion = "{0}.{1}.{2}" -f $version.Major, $version.Minor, ($version.Build + 1)

        # Set new version from repo
        $newVersion = (& GitVersion.exe /output json /showvariable SemVer)
        # Get list of public functions
        $Public  = @( Get-ChildItem -Path ".\$ModuleName\Public\*.ps1" -ErrorAction SilentlyContinue )
        # Prepare comma list of public funtion names for psd1 functions to export
        $PublicFunctions = "'$($Public.BaseName -join "', '")'"

        $replacements = @{

            "ModuleVersion = '.*'" = "ModuleVersion = '$newVersion'"
            'FunctionsToExport = @\(\)' = "FunctionsToExport = @($PublicFunctions)"

        }

        $replacements.GetEnumerator() | ForEach-Object {

            $manifestContent = $manifestContent -replace $_.Key, $_.Value

        }
        
        $manifestContent | Set-Content -Path "$env:Build_SourcesDirectory/$script:moduleManifestFile"

    } catch {

        Write-Error -Message $_.Exception.Message
        $host.SetShouldExit($LastExitCode)

    }
}
#endregion

#region Build
Task Build {

    if (-not (Test-Path "$env:Build_SourcesDirectory/Output/$ModuleName")) {

        New-Item -Path "$env:Build_SourcesDirectory/Output/$ModuleName" -ItemType Directory -Force

    }    

    Copy-Item -Path "$env:Build_SourcesDirectory/Release-Notes.md" -Destination "$env:Build_SourcesDirectory/Output/Release-Notes.md" -Force
    Copy-Item -Path "$env:Build_SourcesDirectory/$ModuleName/en-US" -Filter *.xml -Recurse -Destination "$env:Build_SourcesDirectory/Output/$ModuleName/en-US/" -Force -ErrorAction SilentlyContinue
    Copy-Item -Path "$env:Build_SourcesDirectory/$script:moduleManifestFile" -Destination "$env:Build_SourcesDirectory/Output/$ModuleName/$ModuleName.psd1" -Force

    if (-not(Test-Path "$env:Build_SourcesDirectory/Output/$ModuleName/$ModuleName.psm1")) {

        $null = New-Item -Path "$env:Build_SourcesDirectory/Output/$ModuleName/$ModuleName.psm1" -Force

    }

    Get-ChildItem -Path "$env:Build_SourcesDirectory/$ModuleName/Private/*.ps1" -Recurse | Get-Content | Add-Content "$env:Build_SourcesDirectory/Output/$ModuleName/$ModuleName.psm1" -Force
    $Public = @( Get-ChildItem -Path "$env:Build_SourcesDirectory/$ModuleName/Public/*.ps1" -ErrorAction SilentlyContinue -Force )
    $Public | Get-Content | Add-Content "$env:Build_SourcesDirectory/Output/$ModuleName/$ModuleName.psm1" -Force
    #"`$PublicFunctions = '$($Public.BaseName -join "', '")'" | Add-Content "$env:Build_SourcesDirectory/Output/$ModuleName/$ModuleName.psm1" -Force

}
#endregion

#region Test
Task Test {

    Import-Module "$env:Build_SourcesDirectory/Output/$ModuleName/$ModuleName.psd1" -Force
    $res = Invoke-Pester -Script "$env:Build_SourcesDirectory/Tests/$ModuleName.tests.ps1" -PassThru

    if ($res.FailedCount -gt 0) {
        
        throw "$($res.FailedCount) tests failed."
    
    }
}
#endregion

#region Help
Task Help {

    Import-Module "$env:Build_SourcesDirectory/Output/$ModuleName/$ModuleName.psd1" -Force
    New-MarkdownHelp -Module $ModuleName -Force -OutputFolder "$env:Build_SourcesDirectory/docs" -ErrorAction SilentlyContinue
    Update-MarkdownHelp "$env:Build_SourcesDirectory/docs" -ErrorAction SilentlyContinue
    New-ExternalHelp -Path "$env:Build_SourcesDirectory/docs" -OutputPath "$env:Build_SourcesDirectory/Output/$ModuleName/en-US" -Force -ErrorAction SilentlyContinue

}
#endregion

#region Archive
# Synopsis: Create Archive
task Archive {

    Compress-Archive -Path "$env:Build_SourcesDirectory/Output/$ModuleName/" -DestinationPath "$env:Build_SourcesDirectory/Output/$ModuleName.zip"

}
#endregion
