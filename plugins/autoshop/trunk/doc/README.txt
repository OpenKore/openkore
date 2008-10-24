AUTHOR: 
TOPIC:

=head1 NAME

autoshop - an autoshop plugin for openkore

=head1 VERSION

Version 0.8

=head1 DESCRIPTION

The autoshop plugin creates a map of the area and adds players, shops and
chat rooms with different weights.

A player has a weight of 5. If that player has opened a shop the surrounding
fields will bei weighted depending on the distance to that player. Same for
chat rooms. The intension is to find a place where B<our> shop won't overlap
with others.

=head1 USAGE

=head2 configuration

=over

=item autoshop_maxweight

The maximum fieldweight that's accepted to be 'free'. Must be between 0 and 5.
Default is 0.

=item autoshop_tries

Number of tries to find a free place before giving up. Must be between 1 and 100.
Default is 16.

=item autoshop_radius

Start looking for a free place within the given radius. If it fails the radius
will be doubled. Must be between 1 and 14. Default is 5.

=item autoshop_reopenOnClose

Whether or not to reopen the shop when it's closed. Must be 0 or 1. Default is 0.

=back

=head2 commands

=over

=item suggest

Print suitable coordinates

=item shopmap

Dump the contents of the array to a file (C<shopmap.txt>)

=back

=head1 FOR THOSE WHO WANT TO KNOW

In a 30x30 array we save player characters (and homunculi) with a weight of 5.
If they own a shop or if they opened a chat room their surrounding fields will
get weights of 3 to 1. Non-walkable fields (walls, obstacles) cannot be
selected for a possible new position.

Example (size reduced):

 ....1..........
 ...121.........
 ..12321........
 .1235321....... <- there is a shop (5)
 ..12321........
 ...121.X....... <- the X marks our position
 ....1..........
 ...........5... <- the 5 marks another player
 ...............
 ...............
 ...............

 two shops (not overlapping)
 ...1...1.......
 ..121.121......
 .123222321.....
 12354445321.... <- the weights accumulate
 .123222321.....
 ..121.121......
 ...1...1.......


 two shops (overlapping)

 ...1.1.........
 ..12221........
 .1244421.......
 124767421...... <- the '7' mark the players
 .1244421.......
 ..12221........
 ...1.1.........



=head1 AVAILABILITY

C<svn co https://svn.sourceforge.net/svnroot/openkore/plugins/trunk/>

=head1 COPYRIGHT

This source code is licensed under the GNU General Public License, Version 2.
See L<http://www.gnu.org/licenses/gpl.html>

=head1 AUTHOR

Arachno <arachnophobia at users dot sf dot net>

=cut