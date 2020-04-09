#Azure AD information
#Enter Azure AD Tennent ID
$tenant_Id = ""
#Enter Azure AD Client Secret
$client_secret = ""
#Enter azure AD client ID
$client_id = ""

#The name of the Azure AD Group that you want to get your users from
# If you are importing users form multiple groups please comma separate them Example: @("Creators","Explorer")
$SecurityGroups = @("Creators")

###################################################################################################
###################################################################################################

$ms_online_url = 'https://login.microsoftonline.com/'
$auth_url = $ms_online_url+$tenant_Id+'/oauth2/v2.0/token'
$ms_graph_url = 'https://graph.microsoft.com/'
$scope = $ms_graph_url+'.default'


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

foreach($SecurityGroup in $SecurityGroups)
{
    $SecurityGroup = "'$SecurityGroup'"
    $group_url = $ms_graph_url+'v1.0/groups?$filter=displayName eq '+$SecurityGroup
    $az_response = Invoke-RestMethod $group_url -Method 'GET' -Headers $headers
    
    #| Select-Object displayName, userPrincipalName
    $az_aad_group = $az_response.value.id
    
    $az_aad_group_members = Invoke-RestMethod  $ms_graph_url"v1.0/groups/$az_aad_group/members" -Method 'GET' -Headers $headers
    $az_users += $az_aad_group_members.value.mail
      
}
$az_users  