param   (
    [String]$info=$false,
    [String]$logging=$false

)
#Path to the CSV file
$path_to_file = "users.csv"
$logfile = "./progress.log"
#Tableau Personal Access Tokens
$username="" 
$password="" 

#Enter the server base url
$ts_url = ''

$ts_api_ver = '3.6'
# #Enter default site role that the imported users will get
$siteRole_from = 'Explorer'
$siteRole_to = 'Creator'

# ###################################################################################################
# ###########Dont change anything below this line####################################################
# ###################################################################################################
# #Name of the Tableau site
$site_content_uri = ''
# #The url to the tableau site
$ts_site_url = $ts_url+"/api/"+$ts_api_ver+"/sites/"
#Set the page for the loop

# #Define the Array that will hold the Tableau users
$global:ts_users = @()

function func_logging ($text) {
    
    $message = "[{0:yyyy/MM/dd/} {0:HH:mm:ss}]" -f (Get-Date) +", "+ $text 
    
    if($info -eq $true)
    {
        Write-Host  $message
    }
    if($logging -eq $true)
    {
        Write-Output $message | Out-file $logfile -Append -Encoding default
    }
    

}
function func_ImportUsers {
                        
                            $global:csv_users = Import-Csv $path_to_file  | Select-Object user
                            #return $global:csv_users
        }

#Get Tableau Acess Token
$ts_headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$ts_headers.Add("Content-Type", "text/xml")

function func_InvokeRest{param($rest_url, $method)
                $rest_url
                Invoke-RestMethod $rest_url -Method $method -Headers $global:ts_user_headers -SkipCertificateCheck
                return $RestResponse
}
function func_InvokeRestB{param($rest_url, $method, $body)
                Invoke-RestMethod -Uri $rest_url -Method $method -Headers $global:ts_user_headers -Body $body -SkipCertificateCheck
                return $RestResponseB
}
function func_TableauSignin {param($site)
                        
                        #Tableau atthentication API
                        $global:ts_auth_url = $ts_url+'/api/'+$ts_api_ver+'/auth/signin'
                        #Tableau request body
                        $ts_body = "<tsRequest>`n	<credentials`n	  name=`"$username`" password=`"$password`" >`n  		<site contentUrl=`"$site`" />`n	</credentials>`n</tsRequest>"
                        $ts_token_response = func_InvokeRestB -rest_url $global:ts_auth_url -method 'POST' -body $ts_body -SkipCertificateCheck
                        $ts_token_response = $ts_token_response.tsResponse            
                        # #Get the token that is used for authentication
                        $global:ts_token = $ts_token_response.credentials.token
                        #Get site id
                        $global:ts_site = $ts_token_response.credentials.site.id          
}

function func_TableauHeader{ param()
                        #Tableau header
                        $ts_user_headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
                        $ts_user_headers.Add("Content-Type", "application/xml")
                        $ts_user_headers.Add("x-tableau-auth", $global:ts_token)
                        $global:ts_user_headers= $ts_user_headers
}

function func_getSiteInfo{
                            #Write-Host "ts_site_url " $ts_site_url
                            $ts_user_response = func_InvokeRest -rest_url $ts_site_url -method 'GET'  
                            
                            $global:ts_sites = $ts_user_response.tsResponse.sites
                            #write-host "global:ts_sites.site: " $ts_user_response
                            foreach($site in $global:ts_sites.site)
                            {
                                $page = 1
                                func_logging -text "Collecting information from site $($site.name)"   
                                func_TableauSignin -site $site.contentUrl
                                func_TableauHeader
                                
                                $ts_site_url_id = $ts_site_url+$site.id
                                    
                                $ts_user_response = func_InvokeRest -rest_url $ts_site_url_id -method 'GET'     
                                $ts_site_id = $ts_user_response.tsResponse.site.id
  
                                do{
                                        #$site_role_filter
                                        $site_role_filter = $ts_site_url+$ts_site_id+'/users?filter=siteRole:eq:'+$siteRole_from+'&pageSize=100&pageNumber='+$page
                                        $user_list = func_InvokeRest -rest_url $site_role_filter -method 'GET' 
                                        
                                        #Get number totan number of objects 
                                        [int]$totalAvailable = $user_list.tsResponse.pagination.totalAvailable
                                        #Write-Host "Total aavailable "  $totalAvailable
                                        #Get the size of the page. Defualt is 100
                                        [int]$pageSize = $user_list.tsResponse.pagination.pageSize
                                        #Write-Host "Page size "  $pageSize

                                        #Get the number of pages  and round it up 
                                        if([int]$totalAvailable -gt 0)
                                        {
                                            $maxPages = [math]::ceiling([int]$totalAvailable / [int]$pageSize)
                                        }
                                        else {
                                            $maxPages = 0
                                        }
                                        #Write-Host "max page " $maxPages
                                       
                                        if($user_list.tsResponse.users){

                                            foreach($user in $user_list.tsResponse.users.user)
                                            {
                                                
                                                $obj = New-Object -TypeName PSObject
                                                $obj | Add-Member -MemberType NoteProperty -Name user_id -Value $user.id
                                                $obj | Add-Member -MemberType NoteProperty -Name user -Value $user.name
                                                $obj | Add-Member -MemberType NoteProperty -Name site_id -Value $site.id
                                                $obj | Add-Member -MemberType NoteProperty -Name site_name -Value $site.name
                                                $obj | Add-Member -MemberType NoteProperty -Name contentUrl -Value $site.contentUrl 
                                                $global:ts_users += $obj
                                                
                                            }
                                        }
                                        #Do a loop if there are more than one pages in the loop
                                        if($maxPages -gt 1)
                                        {
                                                $page++
                                        } 
                                    #write-host "Page: " $page
                                    #Continue processing until $Page is greater than maxPage
                                    }until([int]$page -gt [int]$maxPages)  

                                    func_logging -text  "Found $($($ts_users | Measure-Object).Count) with site role $($siteRole_from)"   

                                func_compareUsers                               
                                func_updateUser
                        }                                 
                        #write-host "global:ts_users: " $global:ts_users.user                  
}

function func_compareUsers{

                                $delta = $( Compare-Object $($global:ts_users.user)  $($global:csv_users.user) -IncludeEqual | Where-Object{$_.SideIndicator -eq '=='}).InputObject                          
                                $global:delta = $delta
                                func_logging -text  "$($($global:delta | Measure-Object).Count) users match agains the users in the CSV file."
                                #write-host "delta: " $global:delta
}

function func_updateUser{
                            $ts_body = "<tsRequest>`n	<user`n	  siteRole=`"$siteRole_to`"  ></user>`n</tsRequest>"
                            
                            ForEach ($user in $global:ts_users | Where-Object{$_.user -in $global:delta})
                            {
                                try{
                                        func_logging -text   "Processing user $($user.user) on site $($user.contentUrl). Updating the user from site role $($siteRole_from) to site role $($siteRole_to)"  
                                        

                                        func_TableauSignin -site $user.contentUrl
                                        func_TableauHeader 
                                        $url = $ts_site_url+$user.site_id+"/users/"+$user.user_id
                                        $update = func_InvokeRestB -rest_url $url -method 'PUT' -body $ts_body 
                                                    
                                    }
                                catch{
                                        $PSItem.Exception.Message
                                    }
                            }
                        
}

function main{
    func_ImportUsers 
    func_TableauSignin -site $site_content_uri
    func_TableauHeader 
    func_getSiteInfo
    
    
}


#Entry point
main