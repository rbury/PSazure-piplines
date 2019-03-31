# Dependent modules to load (Pester, PSScriptAnalyzer, etc.)

@(
    @{ ModuleName = "InvokeBuild"; RequiredVersion = "5.4.6"}
    @{ ModuleName = "Pester"; RequiredVersion = "4.7.3"}
    @{ ModuleName = "PSScriptAnalyzer"; RequiredVersion = "1.18.0"}
)
