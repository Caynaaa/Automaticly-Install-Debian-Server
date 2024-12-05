This script is made to install and configure Debian server services automatically and dynamically.
The installed server services include:
1. SSH
2. Samba
3. DNS Server (Bind9)
4. WebServer (Apache2)
5. Dovecot
6. Postfix
7. Mariadb-Server
8. Roundcube

[how to do it]
1. import the file into the server
2. give execution permission to the file
(   chmod -x file_name   
3. run the file
(   [Path]/file_name   )

[INFO]
For the restore file there is still a bug in roundcube where it cannot reconfigure or the new configuration is not applied
