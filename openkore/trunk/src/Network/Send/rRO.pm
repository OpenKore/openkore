# rRO (Russia)
package Network::Send::rRO;
use strict;

use base 'Network::Send::ServerType0';

*sendBuyBulkVender = *Network::Send::ServerType0::sendBuyBulkVender2;

1;
