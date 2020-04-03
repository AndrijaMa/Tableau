#Azure AD information
#Enter Azure AD Tennent ID
$tenant_Id = "****"
#Enter Azure AD Client Secret
$client_secret = "****"
#Enter azure AD client ID
$client_id = "****"
$ms_online_url = 'https://login.microsoftonline.com/'
$auth_url = $ms_online_url+$tenant_Id+'/oauth2/v2.0/token'
$ms_graph_url = 'https://graph.microsoft.com/'
$scope = $ms_graph_url+'.default'

#Enter the server base url
$ts_url = 'http://****'
#Enter the Tableau api version
$ts_api_ver = '3.4'

$ts_user = '****'
$ts_password = '****'

$ts_site_name = 'Home'

$SecurityGroup = "Creators"
#Enter default site role
$siteRole = 'Viewer'

###################################################################################################
###################################################################################################
$ts_auth_url = $ts_url+'/api/'+$ts_api_ver+'/auth/signin'

#Get Tableau Acess Token
$ts_headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$ts_headers.Add("Content-Type", "text/xml")

$ts_body = "<tsRequest>`n    <credentials name=`"$ts_user`" password=`"$ts_password`">`n    	<site contenturl=`"`"/>`n    </credentials>`n</tsRequest>"

$ts_token_response = Invoke-RestMethod $ts_auth_url -Method 'POST' -Headers $ts_headers -Body $ts_body
$ts_token_response = $ts_token_response.tsResponse

$ts_token = $ts_token_response.credentials.token
$ts_site = $ts_token_response.credentials.site.id
$ts_site_url = $ts_url+"/api/"+$ts_api_ver+"/sites/"+$ts_site+"/users"

$ts_user_headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$ts_user_headers.Add("Content-Type", "application/xml")
$ts_user_headers.Add("x-tableau-auth", $ts_token)

$ts_user_response = Invoke-RestMethod $ts_site_url -Method 'GET' -Headers $ts_user_headers
$ts_users = $ts_user_response.tsResponse.users.user.name

#Get Azure Access Token
$az_headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$az_headers.Add("Content-Type", "application/x-www-form-urlencoded")
#$headers.Add("SdkVersion", "postman-graph/v1.0")
$az_body = "grant_type=client_credentials&client_id="+$client_id+"&client_secret="+$client_secret+"&scope="+$scope
$az_token_response = Invoke-RestMethod $auth_url -Method 'POST' -Headers $az_headers -Body $az_body

#List Azure AD Users
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
#$headers.Add("SdkVersion", "postman-graph/v1.0")
$headers.Add("Authorization", "Bearer "+ $az_token_response.access_token )
$SecurityGroup = "'$SecurityGroup'"

$group_url = $ms_graph_url+'v1.0/groups?$filter=displayName eq '+$SecurityGroup
 
$az_response = Invoke-RestMethod $group_url -Method 'GET' -Headers $headers

#| Select-Object displayName, userPrincipalName
$az_aad_group = $az_response.value.id

$az_aad_group_members = Invoke-RestMethod  $ms_graph_url"v1.0/groups/$az_aad_group/members" -Method 'GET' -Headers $headers

$az_users = $az_aad_group_members.value.mail

$ts_site_id = $ts_url+"/api/3.4/sites/"+$ts_site_name+"?key=name"

$siteid = Invoke-RestMethod $ts_site_id -Method 'GET' -Headers $ts_user_headers 
$siteid = $siteid.tsResponse.site.ID

$delta = Compare-Object $ts_users $az_users | Where-Object{$_.SideIndicator -eq '=>'}

#Loop over all users and add the AD users that are missing in Tableau that contain the filter value if a filter is in use 
ForEach ($user in $delta.InputObject)
{
        try{
                $ts_user_body = "<tsRequest>`n	<user name=`"$user`" siteRole=`"$SiteRole`">`n		`n	</user>`n</tsRequest>"
                $create = Invoke-RestMethod $ts_site_url -Method 'POST' -Headers $ts_user_headers -Body $ts_user_body
                $user_id = $create.tsResponse.user.id

                $ts_update_user_body = "<tsRequest>`n	<user	email=`"+$user+`"`n			password=`"$user_password`"`n			/>`n</tsRequest>"
                $ts_update_url = $ts_url+'/api/3.4/sites/'+$siteid+'/users/'+$user_id

                $update = Invoke-RestMethod $ts_update_url -Method 'PUT' -Headers $ts_user_headers -Body $ts_update_user_body
                Write-Host "Added "$user" to Tableau server as site role " $siteRole
        }
        catch{
                $PSItem.Exception.Message
        }

            
}