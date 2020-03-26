param   (
    [Parameter(Mandatory=$false,HelpMessage="Please enter the License key or type Trial to activeate a 14 day trial")] [String]$LicenseKey,
    [Parameter(Mandatory=$false)] [String]$Bootstrap=$false,
    [Parameter(Mandatory=$false)] [String]$Help,
    [Parameter(Mandatory=$true,HelpMessage="Please enter the version of Tableau Server that you want to download (Example:2019.3.4")] 
    [ValidateLength(8,9)]
    [ValidateScript(
                    {
                        If ($_ -match '\d{4}[.]\d{1}[.]\d{1,2}') 
                        {
                            $True
                        } 
                        Else 
                        {
                            Throw "$_ does not match the expected format. The correct format should be xxxx.xx.xx (Example:2019.4.1)"
                        }
                    }
                    )
    ]
    [string]$version=2019.3.4
)
function func_Version ($version) {
   
    if(!$Version)
    {
        Write-Host "-Version is missing a value. It should be in the format xxxx.x.x like for example 2019.1.4 or type Trial to active a 14 day trial"
    }
    elseif($version.ToString().Length -ne 8)
    {
        Write-Host "-Version is in the wrong format. It should be in the format xxxx.x.x like for example 2019.1.4"
        
    }

    elseif($version.ToString().Length -eq 8)
            {
            if ($version -like '*.*')
            {
                $global:major = $version.substring(0,4)
                $global:minor = $version.substring(0,$version.lastindexof('.')).substring(5)
                $global:hotfix = $version.substring($version.length-1)
                
            }
            elseif ($version -like '*-*')
            {
                $version = $version.ToString().replace('-','.') 
                $global:major = $version.substring(0,4)
                $global:minor = $version.substring(0,$version.lastindexof('.')).substring(5)
                $global:hotfix = $version.substring($version.length-1)
                
            }
        }
        #return $global:major, $global:minor, $global:hotfix
}

$github_url = "https://raw.githubusercontent.com/AndrijaMa/Test/master/"
$folder = "C:\Downloads\"
$reg_file = "reginfo.json"
$iDP_config = "iDP_config.json"
$log_file = "install.log"
$event_file = "event.log"
$bootstrapfile = "bootstrap.json"

$global:major = ''
$global:minor = ''
$global:hotfix = ''
$global:DownloadFile = ''


function Write-ToLog ($text) {
    
    $message = "[{0:yyyy/MM/dd/} {0:HH:mm:ss}]" -f (Get-Date) +", "+ $text 
    Write-Host  $message
    Write-Output $message | Out-file $folder$event_file -Append -Encoding default

}

function func_Download($github_url, $folder, $reg_file, $iDP_config, $log_file, $event_file,$version_major, $version_minor, $version_hotfix){
    
    try{#Set the path  to the server version of Tableau that you want to download
        $global:DownloadFile = "TableauServer-64bit-"+$version_major+"-"+$version_minor+"-"+$version_hotfix+".exe"
        $url = "https://downloads.tableau.com/esdalt/"+$version_major+"."+$version_minor+"."+$version_hotfix+"/"+$DownloadFile

        if(Test-Path $folder)
        {
            Write-ToLog -text  'The ' $folder 'folder already exists'
        }
        else
            {
                New-Item -Path $folder -ItemType Directory
                Write-ToLog -text  'Created folder ' $folder
            }
        Write-ToLog -text $url
        #Download the server installation file
        if(Test-Path $($folder+$DownloadFile))
        {
            Write-ToLog -text "Downloading Tableau Server installation media download..." 
            Write-ToLog -text  $($folder+$DownloadFile) ' exists'
        }
        else 
        {
            
            Invoke-WebRequest -Uri $url -OutFile $($folder+$DownloadFile)
            Write-ToLog -text "Download of Tableau Server installation media completed successfully"    
            #Write-ToLog -text "The download is" (Get-Item $($folder+$DownloadFile)).length/1GB " GB and the download took " 
        }
        

        #Download reg_file
        Write-ToLog -text  "Downloading regfile"
        if(Test-Path $($folder+$reg_file))
        {
            Write-ToLog -text  $($folder+$reg_file) ' already exists'
        }
        else
        {
            Invoke-WebRequest -Uri $github_url$reg_file -OutFile $folder$reg_file
            Write-ToLog -text "Download of regfile completed successfully"
        }

        #Download iDP file
        Write-ToLog -text  "Downloading iDP config file"
        if(Test-Path $($folder+$iDP_config))
        {
            Write-ToLog -text  $($folder+$iDP_config) ' already exists'
        }
        else {
            Invoke-WebRequest -Uri $github_url$iDP_config -OutFile $folder$iDP_config
            Write-ToLog -text "Download of iDP config file completed successfully"            
        }

    }
    catch
        {
            Write-ToLog -text $PSItem.Exception.Message
        }
}

function func_Install($file_path, $log_path)
{
    
        try {

                #Install Switches and Properties for Tableau Server
                #https://help.tableau.com/current/server/en-us/silent_installer_flags.htm
                #Start silent Tableau server installation

                if((Test-Path HKLM:\SOFTWARE\Tableau\) -eq $false)
                {
                    Write-ToLog -text  "Starting Tableau Server installation"
                    Start-Process -FilePath $file_path -ArgumentList "/install /silent /ACCEPTEULA = 1 /LOG '$log_path'" -Verb RunAs -Wait
                    Write-ToLog -text  "Tableau Server installation completed successfully"
                }
                else
                {
                    Write-ToLog -text  'Tableau server is already installed'
                }

                #Generate bootstrap file
                if($Bootstrap -eq $true)
                {
                    Write-ToLog -text  "Creating bootstrap file in " $folder
                    Invoke-Expression "tsm topology nodes get-bootstrap-file --file '$($folder+$bootstrapfile)'"
                }
        }
        catch
            {
                Write-ToLog -text $PSItem.Exception.Message
            }
}

function func_License(){

}
function func_Configure($folder, $reg_file, $iDP_config, $log_file, $event_file, $LicenseKey)
{
                                
            try{
                    #Identifying path to TSM
                    #Get-ItemProperty -Path HKLM:\SOFTWARE\Tableau $version_full*
                    Write-ToLog -text "Adding TSM to local Windows system PATH"
        
                    #Check if Tableau is installed on the Server
                    if((Test-Path HKLM:\SOFTWARE\Tableau\) -eq $true)
                    {
                        #Get the AppVersion Property from the registry that contains the path to the 
                        $packages =  ((Get-Item "HKLM:\SOFTWARE\Tableau\Tableau Server *\Directories" | Get-ItemProperty | Select-Object Application).Application+"Packages")
                        $bin = (Get-ItemProperty ($packages+"\bin.*") | Select-Object Name).Name
                        $tsm_path = $packages+"\"+$bin+"\";
                        #Add TSM to Windows Path

                        $Env:path += $tsm_path

                    }

                #Activate Tableau Server license
                Write-ToLog -text  "Registering Tableau Server License"
                Invoke-Expression "tsm licenses activate -k '$LicenseKey'"
                Write-ToLog -text "Completed Tableau Server license activation"
                
                #Register Tableau Server
                $reg_file = $($folder+$reg_file)
                Write-ToLog -text "Starting Tableau Server registration"
                Invoke-Expression "tsm register --file '$reg_file'"
                Write-ToLog -text "Completed Tableau Server registration"

                #Set local repository
                $iDP_file = $($folder+$iDP_config)
                Write-ToLog -text "Starting Tableau Server local Repository setup"
                Invoke-Expression "tsm settings import -f '$iDP_file'"
                Write-ToLog -text "Completed Tableau Server local Repository setup"

                #Apply pending changes
                Write-ToLog -text "Applying pending TSM changes"
                Invoke-Expression "tsm pending-changes apply"
                Write-ToLog -text "TSM changes applied successfully."

                #Initialize configuration
                Write-ToLog -text "Initializing Tableau Server"
                Invoke-Expression "tsm initialize"
                Write-ToLog -text "Tableau Server initialized"

                #Initialize configuration
                Write-ToLog -text "Starting Tableau Server"
                Invoke-Expression "tsm start"
                Write-ToLog -text "Tableau Server started"
            }
            catch
            {
                Write-ToLog -text $PSItem.Exception.Message
            }
}

function func_main(){
    
    func_Version -Version $Version
    #Download Tableau sewrver installation files
    func_Download -github_url $github_url -folder $folder -reg_file $reg_file -iDP_config $iDP_config -log_file $log_file  -event_file $event_file -version_major $global:major -version_minor $global:minor -version_hotfix $global:hotfix
    #Install Tableau server
    func_Install -log_path $($folder+$log_file) -file_path $($folder+$global:DownloadFile)
    #Configure tableau server
    func_Configure -folder $folder -reg_file $reg_file -iDP_config $iDP_config -log_file $log_file  -event_file $event_file -LicenseKey $LicenseKey
}

func_main

