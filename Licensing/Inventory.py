from bs4 import BeautifulSoup  as bs
import requests
import pandas as pd
import math

base_url = '' #Tableau server base url with no trailing slash
api_version = '' #Tableau Server API version (https://help.tableau.com/current/api/rest_api/en-us/REST/rest_api_concepts_versions.htm)
name = "" #Personal Access Token Name (https://help.tableau.com/current/server/en-us/security_personal_access_tokens.htm)
token = "" #Personal Access Token key
#****************************************************************************************************************
#****************************************************************************************************************
df_site = pd.DataFrame(columns=['SiteID','SiteName','SiteCuntentUrl'])
df_user = pd.DataFrame(columns=['SiteName''SiteID','UseName','UserRole'])

if base_url[-1] == '/':
      base_url = base_url[:-1]
else:
  base_url

url = base_url+"/api/"+api_version+"/auth/signin"

payload = '<tsRequest>\n\t<credentials\n\t  personalAccessTokenName=\"'+name+'\" personalAccessTokenSecret=\"'+token+'\" >\n  \t\t<site contentUrl=\"\" />\n\t</credentials>\n</tsRequest>'
headers = {'Content-Type': 'text/xml'}

response = requests.request("POST", url, headers=headers, data=payload)
soup = bs(response.text)
token = soup.credentials['token']

#list all sites
url = base_url+"/api/"+api_version+"/sites/"
headers = {'x-tableau-auth': token,'Content-Type': 'application/xml'}
s = requests.request("GET", url, headers=headers)
sites = bs(s.text)

if int(sites.pagination['totalavailable']) <= 100:
  sitePageCount = 1
else:
 sitePageCount = int(str(round(int(sites.pagination['totalavailable'])/100,0)).split(".", 1)[0])
x=1

while x <= sitePageCount:
  #print(x)
  url = base_url+"/api/"+api_version+"/sites?pageSize=100&pageNumber="+str(x)
  x = x+1
  s = requests.request("GET", url, headers=headers)
  sites = bs(s.text)

  for site in sites.sites:

    SiteName = site['name']
    SiteID = site['id']
    SiteContentUrl = site['contenturl']

    df_site = df_site.append({
                    'SiteName' : SiteName,
                    'SiteID' : SiteID,
                    'SiteContentUrl' : SiteContentUrl

                  }, ignore_index=True,)

switchUrl = base_url+"/api/"+api_version+"/auth/switchSite"


for index, site in df_site.iterrows():
  
  contentUrl = site['SiteContentUrl']
  siteName = site['SiteName']
  siteID = site['SiteID'] 
  #print(contentUrl)
  headersx = {'x-tableau-auth': token, 'Content-Type': 'application/xml'}
  #print(headersx)
  payloadx = "<tsRequest>\t\n  \t\t<site contentUrl=\""+contentUrl+"\" />\n</tsRequest>"
  #print("Payload: "+payloadx)
  responsex = requests.request("POST", switchUrl, data=payloadx,headers=headersx)
  soupx = bs(responsex.text)
  #print(soupx)
  token = soupx.credentials['token']
  #print("Site token: "+token)

  payloadA=""
  headersx = {'x-tableau-auth': token, 'Content-Type': 'application/xml'}
  final_url = base_url+"/api/"+api_version+"/sites/"+siteID+"/users"
  #print(final_url)
  u = requests.request("GET", final_url, headers=headersx,data=payloadA)
  users = bs(u.text)
  #print(users)
  totalavailable = int(users.pagination['totalavailable'])
  #print("totalavailable: " + str(totalavailable))

  if totalavailable <= 100:
    userPageCount = 1
  else:
    userPageCount = math.ceil(totalavailable/100)
  uc=1
  #print(userPageCount)
  
  while uc <= userPageCount:  
    #print("TotalPageCount: "+ str(userPageCount) +  " Current page: "+str(uc))
    users_url = base_url+"/api/"+api_version+"/sites/"+siteID+"/users?pageSize=100&pageNumber="+str(uc)
    uc=uc+1
    
    #print(users_url)
    ud = requests.request("GET", users_url, headers=headersx,data=payloadA)
    userdata = bs(ud.text)
    
    for user in userdata.users:

        userName = user['name']
        userRole = user['siterole']
        #print("Site: " + siteName + " User: "+ userName)  
        df_user = df_user.append({
                    'SiteID' : siteID,
                    'SiteName' : contentUrl,
                    'UserName' : userName,
                    'UserRole' : userRole

                  }, ignore_index=True,)  
      
df_user['UserRole'] = df_user['UserRole'].replace(['ServerAdministrator'],'Creator')
df_user['UserRole'] = df_user['UserRole'].replace(['SiteAdministratorCreator'],'Creator')
df_user['UserRole'] = df_user['UserRole'].replace(['ExplorerCanPublish'],'Explorer')
df_user['UserRole'] = df_user['UserRole'].replace(['SiteAdministratorExplorer'],'Explorer')
df_user.drop( df_user[ df_user['UserRole'] == 'Unlicensed' ].index , inplace=True)

user_list = df_user.sort_values('UserRole').drop_duplicates(subset=['UserName'])
role_list = user_list[['UserName','UserRole']]
licenses = role_list['UserRole'].value_counts()

print(licenses)
