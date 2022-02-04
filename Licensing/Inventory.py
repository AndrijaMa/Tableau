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
df_user = pd.DataFrame(columns=['SiteName''SiteID','UseName','UserRole'])

#Authenticate and save auth token
auth_url = base_url+"/api/"+api_version+"/auth/signin"
payload = '<tsRequest>\n\t<credentials\n\t  personalAccessTokenName=\"'+name+'\" personalAccessTokenSecret=\"'+token+'\" >\n  \t\t<site contentUrl=\"\" />\n\t</credentials>\n</tsRequest>'
headers = {'Content-Type': 'text/xml'}
token = (bs((requests.request("POST", auth_url, headers=headers, data=payload)).text)).credentials['token']

#List all sites and write them to a dataframe
url = base_url+"/api/"+api_version+"/sites/"

#Swithch between sites
switchUrl = base_url+"/api/"+api_version+"/auth/switchSite"

headers = {'x-tableau-auth': token,'Content-Type': 'application/xml'}
sites =  bs((requests.request("GET", url, headers=headers)).text)

#Check how many loops will be executed
sites_count = int(sites.pagination['totalavailable'])
site_page_count = math.ceil(int(sites.pagination['totalavailable'])/100)
sitePageCount = 1 if sites_count <= 100 else site_page_count

x=1
while x <= sitePageCount:
  #print(x)
  url_sites = base_url+"/api/"+api_version+"/sites?pageSize=100&pageNumber="+str(x)
  x = x +1
  sites = bs(requests.request("GET", url_sites, headers=headers).text)

  for site in sites.sites:

    #Authenticate to new site in the loop
    contentUrl = site['contenturl']
    siteName = site['name']
    siteID = site['id'] 
    #print(contentUrl)
    
    headers = {'x-tableau-auth': token, 'Content-Type': 'application/xml'}
    #print(headersx)
    payload = "<tsRequest>\t\n  \t\t<site contentUrl=\""+contentUrl+"\" />\n</tsRequest>"
    #print("Payload: "+payloadx)
    token = (bs(requests.request("POST", switchUrl, data=payload,headers=headers).text)).credentials['token']

    payload=""
    headers = {'x-tableau-auth': token, 'Content-Type': 'application/xml'}
    url_users = base_url+"/api/"+api_version+"/sites/"+siteID+"/users"
    #print(final_url)
    users = bs(requests.request("GET", url_users, headers=headers,data=payload).text)
    
    #print(users)
    #Check how many loops will be executed
    user_count = int(users.pagination['totalavailable'])
    user_page_count = math.ceil(int(users.pagination['totalavailable'])/100)
    userPageCount = 1 if user_count <= 100 else user_page_count
    
    uc=1
    while uc <= user_page_count:  
      #print("TotalPageCount: "+ str(userPageCount) +  " Current page: "+str(uc))
      users_url = base_url+"/api/"+api_version+"/sites/"+siteID+"/users?pageSize=100&pageNumber="+str(uc)
      uc = uc + 1
      
      #print(users_url)
      userdata = bs(requests.request("GET", users_url, headers=headers,data=payload).text)
      
      for user in userdata.users:
        print(user)
        df_user = df_user.append({
                      'SiteID' : site['id'],
                      'SiteName' : site['contenturl'],
                      'UserName' : user['name'],
                      'UserRole' : user['siterole']
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
