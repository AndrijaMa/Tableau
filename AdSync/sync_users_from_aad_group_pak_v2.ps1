#Azure AD information
#Enter Azure AD Tennent ID
$tenant_Id = ""
#Enter azure AD client ID
$client_id = ""
#Enter Azure AD Client Secret
$client_secret = ""

#The name of the Azure AD groups that the script will import the users from 
$SecurityGroups = @("SE_Tableau")

#Tableau Server information 
#Enter the server base url
$ts_url = ''
#Enter the Tableau api version
$ts_api_ver = '3.7'

#Create the Personal Access Tokens from the Site Settings gage
$personalAccessTokenName="" 
$personalAccessTokenSecret="" 

#The name of the site to where the users will be imported to
$site_content_uri = 'Default'  

#Enter default site role
$siteRole = 'Viewer'

###################################################################################################
###########Dont change anything below this line####################################################
###################################################################################################
#Define paths to the Graph API
$ms_online_url = 'https://login.microsoftonline.com/'
$auth_url = $ms_online_url+$tenant_Id+'/oauth2/v2.0/token'
$ms_graph_url = 'https://graph.microsoft.com/'
$scope = $ms_graph_url+'.default'

#Tableau atthentication API
$ts_auth_url = $ts_url+'/api/'+$ts_api_ver+'/auth/signin'

#Get Tableau Acess Token
$ts_headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$ts_headers.Add("Content-Type", "text/xml")

#Tableau request body
$ts_body = "<tsRequest>`n	<credentials`n	  personalAccessTokenName=`"$personalAccessTokenName`" personalAccessTokenSecret=`"$personalAccessTokenSecret`" >`n  		<site contentUrl=`"$site_content_uri`" />`n	</credentials>`n</tsRequest>"
$ts_token_response = Invoke-RestMethod $ts_auth_url -Method 'POST' -Headers $ts_headers -Body $ts_body -SkipCertificateCheck
$ts_token_response = $ts_token_response.tsResponse

#Get the token that is used for authentication
$ts_token = $ts_token_response.credentials.token
#Get site id
$ts_site = $ts_token_response.credentials.site.id
#The url to the tableau site
$ts_site_url = $ts_url+"/api/"+$ts_api_ver+"/sites/"+$ts_site+"/users"

#Tableau header
$ts_user_headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$ts_user_headers.Add("Content-Type", "application/xml")
$ts_user_headers.Add("x-tableau-auth", $ts_token)

#Set the page for the loop
$page = 1
#Define the Array that will hold the Tableau users
$ts_users = @()
do{
        #Define base url to support paging
        $ts_site_url = $ts_url+"/api/"+$ts_api_ver+"/sites/"+$ts_site+"/users?pageSize=100&pageNumber="+$page
        
        $ts_user_response = Invoke-RestMethod $ts_site_url -Method 'GET' -Headers $ts_user_headers -SkipCertificateCheck     
        #Get number totan number of objects 
        [int]$totalAvailable = $ts_user_response.tsResponse.pagination.totalAvailable
        #Get the size of the page. Defualt is 50
        [int]$pageSize = $ts_user_response.tsResponse.pagination.pageSize
        #Get the number of pages  and round it up 
        $maxPages = [math]::ceiling([int]$totalAvailable / [int]$pageSize)
    
    
    if($ts_user_response.tsResponse.users){
             #Fetch the Tableau username from the site that you defined in site_content_uri
             foreach($tsu in $ts_user_response.tsResponse.users)
             {
                $obj = New-Object -TypeName PSObject
                $obj | Add-Member -MemberType NoteProperty -Name user -Value $tsu.user.name  
                $ts_users += $obj  
             }
             
         }
        #Do a loop if there are more than one pages in the loop
         if($maxPages -gt 1)
        {
                $page++
        }        
        
}until([int]$page -gt [int]$maxPages)

#Get Azure Access Token
$az_headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$az_headers.Add("Content-Type", "application/x-www-form-urlencoded")

#$headers.Add("SdkVersion", "postman-graph/v1.0")
$az_body = "grant_type=client_credentials&client_id="+$client_id+"&client_secret="+$client_secret+"&scope="+$scope
$az_token_response = Invoke-RestMethod $auth_url -Method 'POST' -Headers $az_headers -Body $az_body -SkipCertificateCheck

#List Azure AD Users
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"

#$headers.Add("SdkVersion", "postman-graph/v1.0")
$headers.Add("Authorization", "Bearer "+ $az_token_response.access_token )

#Create a array  to hold the Azure users
$az_users = @()
#Loop thru all Security groups defined in SecurityGroups
foreach($SecurityGroup in $SecurityGroups)
{
    $SecurityGroup = "'$SecurityGroup'"

    $group_url = $ms_graph_url+'v1.0/groups?$filter=displayName eq '+$SecurityGroup
    
    $az_response = Invoke-RestMethod $group_url -Method 'GET' -Headers $headers -SkipCertificateCheck
    
    #| Select-Object displayName, userPrincipalName
    $az_aad_group = $az_response.value.id
    $member_uri = $ms_graph_url+"v1.0/groups/$az_aad_group/members"
   
    do{
        $az_aad_group_members = Invoke-RestMethod $member_uri -Method 'GET' -Headers $headers -SkipCertificateCheck
         
        foreach($azgm in $az_aad_group_members.value)
        {
            
                 $obj1 = New-Object -TypeName PSObject
                 $obj1 | Add-Member -MemberType NoteProperty -Name mail -Value $azgm.mail
                 $obj1 | Add-Member -MemberType NoteProperty -Name displayName -Value $azgm.displayName
                 $az_users += $obj1                    
        }
        $member_uri = $az_aad_group_members.'@odata.nextlink'
    
    }until (!($member_uri))
    
}
#$az_users 
#Call the site that you want to import the users to
$ts_site_id = $ts_url+"/api/"+$ts_api_ver+"/sites/"+$site_content_uri+"?key=name"

$siteid = Invoke-RestMethod $ts_site_id -Method 'GET' -Headers $ts_user_headers  -SkipCertificateCheck
$siteid = $siteid.tsResponse.site.ID

#Copare the list of Azure users and Tableau users and return Azure users that do not exist on the Tableau server
$delta = $(Compare-Object $($ts_users.user)  $($az_users.mail)  | Where-Object{$_.SideIndicator -eq '=>'}).InputObject
$delta 
#Loop over all Azure users and filter to only return the users that match the delta
 ForEach ($user in $az_users | Where-Object{$_.mail -in $delta})
 {
         try{
                 #Add user to site
                 $user_id = $response.tsResponse.user.id
                 $ts_user_body = "<tsRequest>`n	<user name=`"$($user.mail)`" siteRole=`"$SiteRole`">`n		`n	</user>`n</tsRequest>"
                 $create = Invoke-RestMethod $ts_site_url -Method 'POST' -Headers $ts_user_headers -Body $ts_user_body -SkipCertificateCheck
                 $user_id = $create.tsResponse.user.id
                
                 #Update user properties
                 $ts_update_user_body = "<tsRequest>`n	<user	email=`"$($user.mail)`"`n			fullName=`"$($user.displayName)`"`n			/>`n</tsRequest>"#                         $ts_update_user_body 
                 $ts_update_url = $ts_url+'/api/'+$ts_api_ver+'/sites/'+$siteid+'/users/'+$user_id
                 $update = Invoke-RestMethod $ts_update_url -Method 'PUT' -Headers $ts_user_headers -Body $ts_update_user_body  -SkipCertificateCheck
                        
         }
         catch{
                 $PSItem.Exception.Message
         }
 }
