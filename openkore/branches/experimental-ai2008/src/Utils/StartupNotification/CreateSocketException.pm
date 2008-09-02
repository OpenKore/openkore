##
# MODULE DESCRIPTION: Exception object
#
# <div class="derived">This class is derived from: @CLASS(Exception)</div>
#
# Thrown when @CLASS(StartupNotification::Launcher) failed to create a socket.

package StartupNotification::CreateSocketException;

use Utils::Core::Exception;
use base qw(Exception);

1;
