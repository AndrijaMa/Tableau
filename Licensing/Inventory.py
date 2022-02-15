####
# This script contains functions that demonstrate how to 
# collect user role information from Tableau Server.
#
# To run the script, you must have installed Python 3.x or later, 
#You will have to have the  'requests',bs4, pandas and math library installed:
#
# To run the script you need to modify the Tableau Portal url and Personal Access Token Name and Key,
# where the server address has no trailing slash (e.g. http://localhost).
#The script will only work on Tableau server version 2020.1 and newer

from bs4 import BeautifulSoup  as bs
import requests
import pandas as pd
import math

base_url = '' #Tableau server base url with no trailing slash
name = "" #Personal Access Token Name (https://help.tableau.com/current/server/en-us/security_personal_access_tokens.htm)
token = "" #Personal Access Token key


#****************************************************************************************************************
#*****Do not change anything below this line
#****************************************************************************************************************
api_version = '3.1'
bs_parser = 'html.parser'
#If true remove trailing slash in the base_url 
base_url = base_url[:-1] if base_url[-1] == '/' else base_url

#Function used in the script*************************************************************************************
#****************************************************************************************************************
def apicall(Method,url,payload,headers,):
  result = bs((requests.request(Method, url,data=payload, headers=headers)).text, bs_parser)
  return result
#****************************************************************************************************************  
def f_heades(token):
  headers = {'x-tableau-auth': token, 'Content-Type': 'application/xml'}
  return headers
#****************************************************************************************************************
def page_count(list):
  count = int(list.pagination['totalavailable'])
  page_count = math.ceil(int(list.pagination['totalavailable'])/100)
  pageCount = 1 if count <= 100 else page_count
  return pageCount
#****************************************************************************************************************
df_user = pd.DataFrame(columns=['SiteName''SiteID','UseName','UserRole'])
#****************************************************************************************************************

#Authenticate and save auth token
#Tableau authentication url
auth_url = base_url+"/api/"+api_version+"/auth/signin"
#Define body
payload = '<tsRequest>\n\t<credentials\n\t  personalAccessTokenName=\"'+name+'\" personalAccessTokenSecret=\"'+token+'\" >\n  \t\t<site contentUrl=\"\" />\n\t</credentials>\n</tsRequest>'
#Define header
headers = {'Content-Type': 'text/xml'}
#Authentication token
token = (apicall('POST', auth_url, payload, headers)).credentials['token']


#Empty body
payload=""
#Collect Server API version
#Server info url
ver_url = base_url+"/api/"+api_version+"/serverinfo"
#Authentication header
headers = f_heades(token)
api_version =  apicall('GET', ver_url, payload, headers).serverinfo.restapiversion.text

#New base url with correct API version that was collected in the previous step
base_url = base_url+"/api/"+api_version

#List all sites and write them to a dataframe
#Sites URL
site_url = base_url+"/sites/"

#Swithch between sites
switchUrl = base_url+"/auth/switchSite"

headers = f_heades(token)
#Call apicall function to collect a list of all sites
sites =  apicall('GET', site_url, payload, headers)

#Check how many sites exist. If more than 100 sites are found then envoke paging and divide the number of sites by 100 to 
#
site_pageCount = page_count(sites)

#Process site that were collected in the previous step
x=1

#while x <= sitePageCount:
while x <= site_pageCount:
  #print(x)
  url_sites = base_url+"/sites?pageSize=100&pageNumber="+str(x)
  x = x +1
  sites = apicall('GET', url_sites, payload, headers)

  for site in sites.sites:

    #Authenticate to new site in the loop
    contentUrl = site['contenturl']
    siteName = site['name']
    siteID = site['id'] 
    
    headers = f_heades(token)
    #print(headersx)
    payload = "<tsRequest>\t\n  \t\t<site contentUrl=\""+contentUrl+"\" />\n</tsRequest>"
    #print("Payload: "+payloadx)
    token = (apicall('POST', switchUrl, payload, headers)).credentials['token']
    
    payload=""
    headers = f_heades(token)
    url_users = base_url+"/sites/"+siteID+"/users"
    #print(final_url)
    users = apicall('GET', url_users, payload, headers)
    
    #print(users)
    #Check how many loops will be executed
    user_count = int(users.pagination['totalavailable'])

    userPageCount = page_count(users)
    print("Processing site "+ siteName +" found " + str(user_count) + " users.")

    uc=1
    while uc <= userPageCount:  
      #print("TotalPageCount: "+ str(userPageCount) +  " Current page: "+str(uc))
      users_url = base_url+"/sites/"+siteID+"/users?pageSize=100&pageNumber="+str(uc)
      uc = uc + 1
      
      #print(users_url)
      userdata = apicall('GET', url_users, payload, headers)
      
      for user in userdata.users:

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
