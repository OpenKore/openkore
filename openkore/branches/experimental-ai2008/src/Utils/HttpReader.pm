#########################################################################
#  OpenKore - Asynchronous HTTP client
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
package HttpReader;

use strict;
use XSTools;

use constant CONNECTING => 0;
use constant DOWNLOADING => 1;
use constant DONE => 2;
use constant ERROR => 3;

XSTools::bootModule('Utils::HttpReader');


package StdHttpReader;

use base qw(HttpReader);


package MirrorHttpReader;

use base qw(HttpReader);

1;
