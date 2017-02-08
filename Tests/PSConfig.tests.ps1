$ParentPath = Split-Path -Path (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent) -Parent
Import-Module -Name (Join-Path -Path $ParentPath -ChildPath "PSConfig.psm1")


Describe Add-DefaultConfigurationSource {
    Clear-ConfigurationSource
    InModuleScope PSConfig {
        It "Creates a Default Configuration Source" {
            $Script:ConfigurationSources.Count | Should Be 0
            Add-DefaultConfigurationSource -InputObject @{
                Data = "Hello, World!"
            }
            $Script:ConfigurationSources.Count | Should Be 1
            $Script:ConfigurationSources[0].Name | Should BeExactly "Default Values"
            $Script:ConfigurationSources[0].Type | Should BeExactly "Default"
            $Script:ConfigurationSources[0].Data.PSObject.Properties.Count | Should Be 1
            $Script:ConfigurationSources[0].Data.Data | Should BeExactly "Hello, World!"
        }
    }
}


Describe Add-EnvironmentConfigurationSource {
    Clear-ConfigurationSource
    InModuleScope PSConfig {
        It "Creates an Environment Variable Configuration Source" {
            $Script:ConfigurationSources.Count | Should Be 0
            Add-EnvironmentConfigurationSource
            $Script:ConfigurationSources.Count | Should Be 1
            $Script:ConfigurationSources[0].Name | Should BeExactly "Environment Variables"
            $Script:ConfigurationSources[0].Type | Should BeExactly "Environment"
        }
    }
}


Describe Add-FileConfigurationSource {
    Clear-ConfigurationSource
    It "Creates a Configuration Source from a string data file" {
        Mock -ModuleName PSConfig Get-Content { return 'Data = Hello, World!' }
        Mock -ModuleName PSConfig Test-Path { return $true }

        InModuleScope PSConfig {
            $Script:ConfigurationSources.Count | Should Be 0
            Add-FileConfigurationSource -Path "C:\NotARealPath\Test.txt" -Format "StringData"
            $Script:ConfigurationSources.Count | Should Be 1
            $Script:ConfigurationSources[0].Name | Should BeExactly "C:\NotARealPath\Test.txt"
            $Script:ConfigurationSources[0].Type | Should BeExactly "File/StringData"
            $Script:ConfigurationSources[0].Data.PSObject.Properties.Count | Should Be 1
            $Script:ConfigurationSources[0].Data.Data | Should BeExactly "Hello, World!"
        }
    }

    Clear-ConfigurationSource
    It "Creates a Configuration Source from a Json file" {
        Mock -ModuleName PSConfig Get-Content { return '{"Data": "Hello, World!"}' }
        Mock -ModuleName PSConfig Test-Path { return $true }

        InModuleScope PSConfig {
            $Script:ConfigurationSources.Count | Should Be 0
            Add-FileConfigurationSource -Path "C:\NotARealPath\Test.json" -Format "Json"
            $Script:ConfigurationSources.Count | Should Be 1
            $Script:ConfigurationSources[0].Name | Should BeExactly "C:\NotARealPath\Test.json"
            $Script:ConfigurationSources[0].Type | Should BeExactly "File/Json"
            $Script:ConfigurationSources[0].Data.PSObject.Properties.Count | Should Be 1
            $Script:ConfigurationSources[0].Data.Data | Should BeExactly "Hello, World!"
        }
    }

    Clear-ConfigurationSource
    It "Creates a Configuration Source from a Csv file" {
        Mock -ModuleName PSConfig Import-Csv { return "Data`n" + '"Hello, World!"' | ConvertFrom-Csv }
        Mock -ModuleName PSConfig Test-Path { return $true }

        InModuleScope PSConfig {
            $Script:ConfigurationSources.Count | Should Be 0
            Add-FileConfigurationSource -Path "C:\NotARealPath\Test.csv" -Format "Csv"
            $Script:ConfigurationSources.Count | Should Be 1
            $Script:ConfigurationSources[0].Name | Should BeExactly "C:\NotARealPath\Test.csv"
            $Script:ConfigurationSources[0].Type | Should BeExactly "File/Csv"
            $Script:ConfigurationSources[0].Data.PSObject.Properties.Count | Should Be 1
            $Script:ConfigurationSources[0].Data.Data | Should BeExactly "Hello, World!"
        }
    }
}


Describe Clear-ConfigurationSource {
    Clear-ConfigurationSource
    Add-DefaultConfigurationSource -InputObject @{
        Data = "Hello, World!"
    }
    InModuleScope PSConfig {
        It "Clears the configuration" {
            $Script:ConfigurationSources.Count | Should Be 1
            Clear-ConfigurationSource
            $Script:ConfigurationSources.Count | Should Be 0
        }
    }
}


Describe Get-ConfigurationItem {
    Clear-ConfigurationSource
    Context "No data loaded" {
        It "Returns null" {
            Get-ConfigurationItem -Key "Nonexistent" | Should BeNullOrEmpty
        }
    }

    Add-EnvironmentConfigurationSource
    Context "Environment Variables" {
        It "Returns null when nothing is found" {
            Get-ConfigurationItem -Key "Data" | Should BeNullOrEmpty
        }

        It "Returns environment variables" {
            Get-ConfigurationItem -Key "PSModulePath" | Should BeExactly $env:PSModulePath
        }
    }

    Clear-ConfigurationSource
    Add-DefaultConfigurationSource -InputObject @{
        Data = "Hello, World!"
    }
    Context "Object Values" {
        It "Returns null when nothing is found" {
            Get-ConfigurationItem -Key "Nonexistent" | Should BeNullOrEmpty
        }

        It "Returns data" {
            Get-ConfigurationItem -Key "Data" | Should BeExactly "Hello, World!"
        }
    }

    Clear-ConfigurationSource
    Add-EnvironmentConfigurationSource
    Add-DefaultConfigurationSource -InputObject @{
        Data = "Hello, World!"
    }
    Context "Multiple Values" {
        It "Returns null when nothing is found" {
            Get-ConfigurationItem -Key "Nonexistent" | Should BeNullOrEmpty
        }

        It "Returns data when found in first configuration source" {
            Get-ConfigurationItem -Key "PSModulePath" | Should BeExactly $env:PSModulePath
        }

        It "Returns data when found in second configuration source" {
            Get-ConfigurationItem -Key "Data" | Should BeExactly "Hello, World!"
        }
    }
}

Describe Get-ConfigurationItemsFromMultipleSources {
    Clear-ConfigurationSource
    Add-DefaultConfigurationSource -InputObject @{
        DefaultData = "Hello, Default World!"
    }
    Add-EnvironmentConfigurationSource

    #Needed to mock
    InModuleScope PSConfig {
        Mock -ModuleName PSConfig -Verifiable Get-Content { return 'MockFileData = Hello, Mock World!' }
        Mock -ModuleName PSConfig -Verifiable Test-Path { return $true }
        Add-FileConfigurationSource -Path "C:\NotARealPath\Test.txt" -Format "StringData"
        Assert-VerifiableMocks

        It "Loads from multiple Configuration Sources" {
            $Script:ConfigurationSources.Count | Should Be 3
            (Get-ConfigurationSources).Count | Should Be 3
        }

        $data = $Script:ConfigurationSources[3].Data
        Write-Host $data
        It "Returns data when found in file configuration source" {
            Get-ConfigurationItem -Key "MockFileData" -Verbose | Should BeExactly "Hello, Mock World!"
        }
        It "Returns data when found in default configuration source" {
            Get-ConfigurationItem -Key "DefaultData" | Should BeExactly "Hello, Default World!"
        }
        It "Returns data when found in env configuration source" {
            Get-ConfigurationItem -Key "PATH" | Should Not BeNullOrEmpty
        }
    }
}

Describe Get-ConfigurationItemFromMultipleSourcesWithOverride {
    Clear-ConfigurationSource
    
    Add-DefaultConfigurationSource -InputObject @{
        PATH = "Hello, Default World!"
    }
    It "Returns correct default data" {
        Get-ConfigurationItem -Key "PATH" -Override -Verbose | Should BeExactly "Hello, Default World!"
    }

    Add-EnvironmentConfigurationSource
    It "Returns path environment data overridden" {
        Get-ConfigurationItem -Key "PATH" -Override -Verbose | Should Not BeExactly "Hello, Default World!"
    }

    Mock -ModuleName PSConfig Get-Content { return 'PATH = Path Override' }
    Mock -ModuleName PSConfig Test-Path { return $true }
    Add-FileConfigurationSource -Path "C:\NotARealPath\Test.txt" -Format "StringData"
    It "Returns correctly overridden data when found in additional configuration source" {
        Get-ConfigurationItem -Key "PATH" -Override -Verbose | Should BeExactly "Path Override"
    }
}

Describe Get-FileConfigurationSourceItemWithBadChars {
    Clear-ConfigurationSource
    Mock -ModuleName PSConfig Get-Content { return 'MockFileData = Hello, Mock World!' }
    Mock -ModuleName PSConfig Test-Path { return $true }
    Add-FileConfigurationSource -Path "C:\NotARealPath\Test.txt" -Format "StringData"

    It "Creates a Configuration Source from a string data file" {
        InModuleScope PSConfig {
            $Script:ConfigurationSources.Count | Should Be 1
            $Script:ConfigurationSources[0].Name | Should BeExactly "C:\NotARealPath\Test.txt"
            $Script:ConfigurationSources[0].Type | Should BeExactly "File/StringData"
            $Script:ConfigurationSources[0].Data.PSObject.Properties.Count | Should Be 1
            $Script:ConfigurationSources[0].Data.MockFileData | Should BeExactly "Hello, Mock World!"
        }
    }

    Add-DefaultConfigurationSource -InputObject @{
        DefaultData = "Hello, Default World!"
    }
    Add-EnvironmentConfigurationSource

    It "Returns data when found in file configuration source" {
        Get-ConfigurationItem -Key "MockFileData" | Should BeExactly "Hello, Mock World!"
    }
    It "Returns data when found in default configuration source" {
        Get-ConfigurationItem -Key "DefaultData" | Should BeExactly "Hello, Default World!"
    }
}

Remove-Module -Name "PSConfig"