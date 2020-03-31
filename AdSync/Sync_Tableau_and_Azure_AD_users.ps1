#Azure AD information
#Enter Azure AD Tennent ID
$tenant_Id = ""
#Enter Azure AD Client Secret
$client_secret = ""
#Enter azure AD client ID
$client_id = ""

$auth_url = 'https://login.microsoftonline.com/'+$tenant_Id+'/oauth2/v2.0/token'
$scope = 'https://graph.microsoft.com/.default'

#Enter the server base url
$ts_url = ''
#Enter the Tableau api version
$ts_api_ver = '3.4'

$ts_user = ''
$ts_password = ''
#Enter Filter Property
$filterProperty = 'jobTitle'
#Enter Filter Value
$filterValue = 'Tableau'
#Enter default site role
$siteRole = 'Viewer'
$ts_auth_url = $ts_url+'/api/'+$ts_api_ver+'/auth/signin'

#Get Azure Access Token
$az_headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$az_headers.Add("Content-Type", "application/x-www-form-urlencoded")
#$headers.Add("SdkVersion", "postman-graph/v1.0")
$az_body = "grant_type=client_credentials&client_id="+$client_id+"&client_secret="+$client_secret+"&scope="+$scope
$az_token_response = Invoke-RestMethod $auth_url -Method 'POST' -Headers $az_headers -Body $az_body

#Get Tableau Acess Token
$ts_headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$ts_headers.Add("Content-Type", "text/xml")

$ts_body = "<tsRequest>`n    <credentials name=`"$ts_user`" password=`"$ts_password`">`n    	<site contenturl=`"`"/>`n    </credentials>`n</tsRequest>"

$ts_token_response = Invoke-RestMethod $ts_auth_url -Method 'POST' -Headers $ts_headers -Body $ts_body
$ts_token_response = $ts_token_response.tsResponse

$ts_token = $ts_token_response.credentials.token
$ts_site = $ts_token_response.credentials.site.id

$ts_user_headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$ts_user_headers.Add("Content-Type", "application/xml")
$ts_user_headers.Add("x-tableau-auth", $ts_token)


$ts_api_url = $ts_url+"/api/"+$ts_api_ver+"/sites/"+$ts_site+"/users"

#List Azure AD Users
$az_user_headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
#$headers.Add("SdkVersion", "postman-graph/v1.0")
$az_user_headers.Add("Authorization", "Bearer "+ $az_token_response.access_token )

$az_response = Invoke-RestMethod 'https://graph.microsoft.com/v1.0/users' -Method 'GET' -Headers $az_user_headers

ForEach ($user in ($az_response.value | Where-Object{$_.$filterProperty -eq $filterValue}))
{
    $u = $user.givenName
   
        $ts_user_body = "<tsRequest>`n	<user name=`"$u`" siteRole=`"$SiteRole`">`n		`n	</user>`n</tsRequest>"
        $response = Invoke-RestMethod $ts_api_url -Method 'POST' -Headers $ts_user_headers -Body $ts_user_body
    
    Write-Host "Added "$u" to Tableau server"
    
}





