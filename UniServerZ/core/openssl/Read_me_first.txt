###############################################################################
# Name: Read_me_first.txt
# Created By: The Uniform Server Development Team
# Edited Last By: Mike Gleaves (ric)
# V 1.0 19-3-2013
###############################################################################

 The script Generate_server_cert_and_key.bat generates a self-signed server
 certificate and key pair.

 It assumes you have not changed the server name from its default of localhost.
 
 The certificate and key are automatically generated and installed without any
 user input to folder, UniServerZ\core\apache2\server_certs

 Note 1: The certificate signing request is not required hence is deleted.

 Note 2: SSL is automatically enabled in Apache's configuration file httpd.conf
         as follows:

         a) File name : UniServerZ\core\apache2\conf\httpd.conf

         b) Line changed as follows:
             Original line : #LoadModule ssl_module modules/mod_ssl.so
             Changed to    : LoadModule ssl_module modules/mod_ssl.so

 Note 3: For the changes to take effect restart Apache server.

                                  --- End ---
