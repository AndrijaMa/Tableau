Param(
    [string]$ts_admin_un,
    [string]$ts_admin_pw,
    [string]$reg_first_name,
    [string]$reg_last_name,
    [string]$reg_email,
    [string]$reg_company,
    [string]$reg_title,
    [string]$reg_department,
    [string]$reg_industry,
    [string]$reg_phone,
    [string]$reg_city,
    [string]$reg_state,
    [string]$reg_zip,
    [string]$reg_country,
    [string]$license_key,
    [string]$install_script_url,
    [string]$local_admin_user,
    [string]$local_admin_pass,
    [string]$eula
)

$folder = "C:\tab\" 
$reg_file = "rg.json"
$iDP_config = "cf.json"
$log_file = "install.log"
$event_file = "event.log"
$bootstrapfile = "bootstrap.json"

$global:major = ''
$global:minor = ''
$global:hotfix = ''
$global:DownloadFile = ''
function func_secrets{
    
        $global:local_admin_user = $local_admin_user
        $global:local_admin_pass = $local_admin_pass
        $global:content_admin_user = $ts_admin_un
        $global:content_admin_pass = $ts_admin_pw
        $global:product_keys = $license_key
    
}
function func_regile{ 
   ## 2. make registration.json
#TODO: add parameter for accepting eula
   @{
        first_name = $reg_first_name
        last_name = $reg_last_name
        email = $reg_email
        company = $reg_company
        title = $reg_title
        department = $reg_department
        industry = $reg_industry
        phone = $reg_phone
        city = $reg_city
        state = $reg_state
        zip = $reg_zip
        country = $reg_country
        eula = "yes"
    }| ConvertTo-Json -depth 10 | Out-File $global:folder$reg_file -Encoding ASCII
}

function func_iDPfile{ 
     @{
        configEntities = @{
            identityStore= @{
                _type= "identityStoreType"
                type= "local"
            }
        }
        topologyVersion = @{}
    }| ConvertTo-Json -depth 20 | Out-File $global:folder$iDP_config -Encoding ASCII
      
}
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


function func_createFolder{
                                                   
                            if(Test-Path $folder)
                            {
                                Write-ToLog -text  "'The ' $folder 'folder already exists'"
                            }
                            else
                                {
                                    New-Item -Path $folder -ItemType Directory
                                    Write-ToLog -text  'Created folder ' $folder
                                }
}
function Write-ToLog ($text) {
    
    $message = "[{0:yyyy/MM/dd/} {0:HH:mm:ss}]" -f (Get-Date) +", "+ $text 
    Write-Host  $message
    Write-Output $message | Out-file $folder$event_file -Append -Encoding default

}

function func_Download($folder, $reg_file, $iDP_config, $log_file, $event_file,$version_major, $version_minor, $version_hotfix){
    
    try{#Set the path  to the server version of Tableau that you want to download
        $global:DownloadFile = "TableauServer-64bit-"+$version_major+"-"+$version_minor+"-"+$version_hotfix+".exe"
        $url = "https://downloads.tableau.com/esdalt/"+$version_major+"."+$version_minor+"."+$version_hotfix+"/"+$DownloadFile

        Write-ToLog -text $url
        #Download the server installation file
        if(Test-Path $($folder+$global:DownloadFile))
        {
            Write-ToLog -text "Downloading Tableau Server installation media download..." 
            Write-ToLog -text  $($folder+$DownloadFile) ' exists'
        }
        else
        {
            
            Invoke-WebRequest -Uri $url -OutFile $($folder+$DownloadFile)
            Write-ToLog -text "Download of Tableau Server installation media completed successfully"    
            Write-ToLog -text "The download is" (Get-Item $($folder+$DownloadFile)).length/1GB " GB and the download took " 
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
                    if($global:major -le 2019 -and $global:minor -lt 4 -or $global:major -le 2018 ){
                        Start-Process -FilePath $file_path -ArgumentList " /install /silent /ACCEPTEULA = 1 /LOG '$log_path'" -Verb RunAs -Wait
                    }
                    elseif ($global:major -ge 2019 -and $global:minor -eq 4 -or $global:major -ge 2020) {
                        Start-Process -FilePath $file_path -ArgumentList " /install /passive ACCEPTEULA=1" -Verb RunAs -Wait
                    }

                    Write-ToLog -text  "Tableau Server installation completed successfully"
                }
                else
                {
                    Write-ToLog -text  'Tableau server is already installed'
                }

                #Identifying path to TSM
                #Get-ItemProperty -Path HKLM:\SOFTWARE\Tableau $version_full*
                Write-ToLog -text "Adding TSM to local Windows system PATH"
    
                #Check if Tableau is installed on the Server
                if((Test-Path HKLM:\SOFTWARE\Tableau\) -eq $true)
                {
                    #Get the AppVersion Property from the registry that contains the path to the 
                    if ( (Get-Item "HKLM:\SOFTWARE\Tableau\Tableau Server *\Directories" | Get-ItemProperty | Select-Object Application).Application -eq '\$')
                    {
                        $packages =  ((Get-Item "HKLM:\SOFTWARE\Tableau\Tableau Server *\Directories" | Get-ItemProperty | Select-Object Application).Application+"Packages")
                    }
                    else
                    {
                        $packages =  ((Get-Item "HKLM:\SOFTWARE\Tableau\Tableau Server *\Directories" | Get-ItemProperty | Select-Object Application).Application+"\Packages")
                    }
                    
                    
                    $bin = (Get-ItemProperty ($packages+"\bin.*") | Select-Object Name).Name
                    $global:tsm_path = $packages+"\"+$bin+"\";
                    #Add TSM to Windows Path

                    $Env:path += $global:tsm_path


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

function func_AntiVirus(){
        #Disable antivirus scan for the folder that is being used during the installation
        Write-ToLog -text "Adding C:\Downloads to AV Exlusion"
        Add-MpPreference -ExclusionPath $folder

        if((Test-Path HKLM:\SOFTWARE\Tableau\) -eq $true){
            $ts_install = (Get-Item "HKLM:\SOFTWARE\Tableau\Tableau Server *\Directories" | Get-ItemProperty | Select-Object Application).Application
            Write-ToLog -text $ts_install

            $ts_data =  (Get-Item "HKLM:\SOFTWARE\Tableau\Tableau Server *\Directories" | Get-ItemProperty | Select-Object Data).Data   
            Write-ToLog -text $ts_data 
            
            Add-MpPreference -ExclusionPath $ts_install 
            Write-ToLog -text "Added Tableau server install folder to AntiVirus Exlusions"
            Add-MpPreference -ExclusionPath $ts_data 
            Write-ToLog -text "Added Tableau server data folder to AntiVirus Exlusions"
        }
        }   
function func_Configure($folder, $reg_file, $iDP_config, $log_file, $event_file, $license_key)
{
                                
            try{
                
                $tsm = $global:tsm_path +"tsm.cmd"
                Write-ToLog $tsm
                #Activate Tableau Server license
                Write-ToLog -text  "Registering Tableau Server License"

                if($license_key.ToLower() -eq 'trial'){
                    
                    Start-Process $tsm -ArgumentList " licenses activate -t" -Wait
                    Write-ToLog -text "Completed Tableau Server trial license activation"
                }
                elseif($license_key -match '^[0-9A-Za-z]{4}[-][0-9A-Za-z]{4}[-][0-9A-Za-z]{4}[-][0-9A-Za-z]{4}[-][0-9A-Za-z]{4}$'){
                    
                    Start-Process $tsm -ArgumentList " licenses activate -k $license_key" -Wait
                    Write-ToLog -text "Completed Tableau Server license activation"
                }
               
                
                #Register Tableau Server
                $reg_file = $($folder+$reg_file)
                Write-ToLog -text "Starting Tableau Server registration"
                Start-Process $tsm -ArgumentList " register --file $reg_file" -Wait
               
                Write-ToLog -text "Completed Tableau Server registration"

                #Set local repository
                $iDP_file = $($folder+$iDP_config)
                Write-ToLog -text "Starting Tableau Server local Repository setup"
                Start-Process $tsm -ArgumentList " settings import -f $iDP_file" -Wait
                #Invoke-Expression "tsm settings import -f '$iDP_file'"
                Write-ToLog -text "Completed Tableau Server local Repository setup"

                #Apply pending changes
                Write-ToLog -text "Applying pending TSM changes"
                Start-Process $tsm -ArgumentList " pending-changes apply" -Wait
                #Invoke-Expression "tsm pending-changes apply"
                Write-ToLog -text "TSM changes applied successfully."

                #Initialize configuration
                Write-ToLog -text "Initializing Tableau Server"
                Start-Process $tsm -ArgumentList " initialize" -Wait
                #Invoke-Expression "tsm initialize"
                Write-ToLog -text "Tableau Server initialized"

                #Initialize configuration
                Write-ToLog -text "Starting Tableau Server"
                Start-Process $tsm -ArgumentList " start"  -Wait
                #Invoke-Expression "tsm start"
                Write-ToLog -text "Tableau Server started"
            }
            catch
            {
                Write-ToLog -text $PSItem.Exception.Message
            }
}

function func_main(){
    func_createFolder
    func_regile
    func_iDPfile
    func_secrets
    #Exclude folders from realtime scanning
    func_AntiVirus
    #Set paramaters for the Tableau Server version
    func_Version -Version $Version
    #Download Tableau server installation files
    func_Download  -folder $folder -reg_file $reg_file -iDP_config $iDP_config -log_file $log_file  -event_file $event_file -version_major $global:major -version_minor $global:minor -version_hotfix $global:hotfix
    #Install Tableau server
    #func_Install -log_path $($folder+$log_file) -file_path $($folder+$global:DownloadFile)
    #Configure tableau server
    #func_Configure -folder $folder -reg_file $reg_file -iDP_config $iDP_config -log_file $log_file  -event_file $event_file -LicenseKey $LicenseKey
    #func_AntiVirus
}

func_main