# bRO (Brazil): Odin
package Network::Send::bRO;
use strict;

use base 'Network::Send::ServerType0';

*sendMasterLogin = *Network::Send::ServerType0::sendMasterHANLogin;
*sendBuyBulkVender = *Network::Send::ServerType0::sendBuyBulkVender2;

1;
