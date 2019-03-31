Describe functiontwo {

    Context 'True' {
        It "should know true from false" {
            $true | Should -be $true
        }
    }

    Context 'Numbers' {
        It "Should compare nubmers" {
            2 | Should -be 2
            2 | Should -gt 1
        }
    }

    Context 'Strings' {
        It "Should compare strings" {
            'Test' | Should -BeExactly 'Test'
            'Test'.Length | Should -be 4
        }
    }

    Context 'Arrays' {
        It "Should compare arrays" {
            $array = 1..2
            $result = $array * 2

            $result.Count | Should -be 4
            $result[0] | Should -be 1
            $result[1] | Should -be 2
            $result[2] | Should -be 1
            $result[3] | Should -be 2
        }
    }
}