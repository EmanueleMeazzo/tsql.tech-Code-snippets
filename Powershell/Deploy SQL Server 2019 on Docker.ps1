docker pull mcr.microsoft.com/mssql/server:2019-latest

docker stop sql2019
docker rm sql2019

docker run `
-v sqlvolume:/var/opt/mssql `
-v D:\SQL:/sql `
--name sql2019 `
-p 1433:1433 `
-e "ACCEPT_EULA=Y" `
-e "SA_PASSWORD=This is a password,ok?" `
-d mcr.microsoft.com/mssql/server:2019-latest
