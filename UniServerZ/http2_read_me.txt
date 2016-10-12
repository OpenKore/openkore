#############################################################################
                         Uniform Server Zero XII
#############################################################################
 11-11-2015
 Apache 2.4.17 contains mod_http2, following shows how to install and test.

 Note 1: Currently http/2 over http is not supported. 

 Note 2: Currently only http/2 over TLS/1.2 is supported. To test h2 on Uniform
         Server you must enable SSL and enable the Apache module mod_http2
         as follows: 
#############################################################################

------- 
Install
-------
 1 Start UniController

 2 Create a server certificate:
   From UniController: Apache >  Apache SSL > click "Server Certificate and Key generator"  
   Server Certificate and Key generator form opens click "Generate" button
   A confirmation pop-up displayed, click OK button

 3 From UniController enable module: Apache > Edit Basic and Modules > click "Apache Modules Enable/Disable"
   Apache Modules Enable/Disable form opens.
   Navigate to entry "http2_module" and click check box to the left of it.
   Close form, click cross top right.

 4 Firefox download and install the following  Firefox plugin:
    https://addons.mozilla.org/en-US/firefox/addon/spdy-indicator/

----
Test
----

 5 Start Apache server

 6 Click "View ssl" page button
   Firefox "This connection is untrusted", click "I understand the risks" and click  "Add exception"
   The add security exception form is displayed, click "Confirm Security Exception"
 
 7 Firefox lightning indicator in browser address bar confirms http2 is working.

--------------------------------------o0o------------------------------------
            Copyright 2002-2016 The Uniform Server Development Team
                            All rights reserved.


