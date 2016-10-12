To use the CSR and key generation functions from PHP, you will need to install
an openssl.cnf file.  We have included a sample file that can be used for this
purpose in this folder alongside this readme file.

The default path for the openssl.cnf file is determined as follows:

OPENSSL_CONF environmental variable, if set, is assumed to hold the
path to the file.

If it is not set, SSLEAY_CONF environmental variable is checked next.
If neither are set, PHP will look in the default certificate area that was set
at the time that the SSL DLLs were compiled.  This is typically
"C:\usr\local\ssl\openssl.cnf".

If the default path is not suitable for your system, you can set the
OPENSSL_CONF variable; under windows 95 and 98 you can set this variable in
your autoexec.bat (or the batch file that starts your webserver/PHP).
Under NT, 2000 and XP you can set environmental variables using "My Computer"
properties.

If setting an environmental var is not suitable, and you don't want to install
the config file at the default location, you can override the default path
using code like this:

$configargs = array(
    "config" => "path/to/openssl.cnf"
    );

$pkey = openssl_pkey_new($config);
$csr = openssl_csr_new($dn, $pkey, $config);

Please consult the online manual for more information about these functions.

NOTE!

Windows Explorer gives special meaning to files with a .cnf extension.
This typically means that editing the file from the explorer (by double or
right-clicking) will be difficult or impossible depending on your setup.
It is often easier to open the file from within the editor.
You can avoid this issue by naming the file something else (you might need to
rename the file using a DOS box) and then setting up an environmental variable
as described above.
