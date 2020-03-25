$folder = "C:\Downloads\"

if(Test-Path $folder)
        {
            Write-ToLog -text  'The ' $folder 'folder already exists'
        }
        else
            {
                New-Item -Path $folder -ItemType Directory
                Write-ToLog -text  'Created folder ' $folder
            }
