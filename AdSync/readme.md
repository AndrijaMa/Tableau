# TableauAzureADSync


### **What is TableauAzureADSync?**

TableauAzureADSync is a script built in PowerShell that syncronizes users from Azure Active Directory (AAD) to Tableau Server. 

### **Script Description**
The script uses that [Tableau REST AP](https://help.tableau.com/current/api/rest_api/en-us/REST/rest_api.htm) and the [Microsoft Graph API](https://docs.microsoft.com/en-us/graph/overview) (Built on REST) to syncronize users from Azure AD to Tableau server.

For the script to work you have to: 

1. Create Application in Azure AD [link](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)and give the application permissions to read users and group objects.
2. Get the Subscription ID, Client ID and Client Secret from the Application created in step 1
3. Get the name of the Azure AD group that hosts the Tableau Users
4. Get the url for the Tableau Server
5. Provision a Personal Access Token from the Tableau Server
6. Decide the default Tableau Role that the users provisioned using the script will be assigned.
7. Get the name of the Tableau Site that the users wil be provisioned to.

The script that is in the repository [link](https://github.com/AndrijaMa/Tableau/blob/master/AdSync/sync_users_from_aad_group_pak_v2.ps1) covers a scenario where you have one Tableau site and want to add users that are members of an Azure Active Directory Security group to a Tableau Server that is installed on prem  or in a private cloud.

Download the [script](https://github.com/AndrijaMa/Tableau/blob/master/AdSync/sync_users_from_aad_group_pak_v2.ps1) sync_users_from_aad_group_pak_v2.ps1 and add the information that you collected previously to the top of the script.

```powershell
#Azure AD information
#Enter Azure AD Tennent ID
$tenant_Id = ""
#Enter azure AD client ID
$client_id = ""
#Enter Azure AD Client Secret
$client_secret = ""

#The name of the Azure AD groups that the script will import the users from 
$SecurityGroups = @("")

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
```
