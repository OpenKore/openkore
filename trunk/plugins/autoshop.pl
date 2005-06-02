# $Header$
#
# autoshop by Arachno
#
# This source code is licensed under the
# GNU General Public License, Version 2.
# See http://www.gnu.org/licenses/gpl.html

our $Version = "0.7";
our $maxRad = 14;

package autoshop;

use strict;
use Plugins;
use Settings;
use Globals;
use Utils;
use Misc;
use Log qw(message warning error);
use AI;

my $cvs = 1;

if (defined $cvs) {
  open(MF, "< $Plugins::current_plugin" )
      or die "Can't open $Plugins::current_plugin: $!";
  while (<MF>) {
    if (/Header:/) {
      my ($rev) = $_ =~ /\.pl,v (.*?) [0-9]{4}/i;
      $Version .= "cvs rev ".$rev;
      last;
    }
  }
  close MF;
};
                                        
undef $cvs if defined $cvs;

our @chtRooms;
                                        
Plugins::register('autoshop', 'checks our environment before opening shop', \&Unload, \&Unload);

my $hooks = Plugins::addHooks(
            ['start3', \&checkConfig, undef],
            ['AI_pre', \&autoshop, undef],
            ['Command_post', \&commandHandler, undef],
);

sub Unload {
  Plugins::delHooks($hooks);
  message "autoshop unloaded.\n";
};

# debugging output 	 
sub debug {
  message $_[0], "list" if $::config{autoshop_debug};
};

# checks configuration for silly settings
sub checkConfig {
  my $tpl = "Your %s setting is either too high or too low (%d). Using default value (%d).\n";
  my %configs = ('autoshop_maxweight', '0 5 0', 'autoshop_tries', '1 900 16', 'autoshop_radius', '1 '.$maxRad.' 5');
  while (my ($key, $value) = each(%configs)) {
    my ($min, $max, $def) = split(/ /, $value);
    if ($::config{$key} >= $max || $::config{$key} <= $min) {
      error(sprintf($tpl, $key, $::config{$key}, $def));
      configModify($key, $def);
    };
  }
};

# just a facade for "suggest" and "shopmap"
sub commandHandler {
  my (undef, $param) = @_;
  if ($param->{switch} eq 'suggest')    {suggest_cmdline(); $param->{return} = 1}
  elsif ($param->{switch} eq 'shopmap') {showmap(); $param->{return} = 1}
  elsif ($param->{switch} eq 'autoshop') {showVer(); $param->{return} = 1};
};

# shows version
sub showVer {
  message "autoshop version $Version\n", "list";
  my @cf = ('autoshop', 'shopAuto_open', 'autoshop_maxweight', 'autoshop_tries',
            'autoshop_radius', 'autoshop_debug');
  foreach (@cf) {message(sprintf("%s %d\n", $_, $::config{$_}))};
};

# manual search for a free place
sub suggest_cmdline {
  clearVendermap(); buildVendermap();
  my ($x, $y, $success) = suggest($::config{autoshop_radius});
  if ($success) {
    message "this would be a nice place for a shop: $x $y\n", "list";
  } else {
    message "could not find a free place. Try increasing autoshop_maxweight.\n", "list";
  };
};

# walk to arg1, arg2
sub walkto {
  my %args;
  $args{move_to}{x} = $_[0];
  $args{move_to}{y} = $_[1];
  $args{time_move} = $char->{time_move};
  $args{ai_move_giveup}{timeout} = $timeout{ai_move_giveup}{timeout};
  debug("moving to: $_[0] $_[1])");
  AI::queue("move", \%args);
};

# suggests new coordinates
sub suggest {
  my $radius = shift;
  if ($radius > $maxRad) {$radius = $maxRad};
  debug("looking for suitable coordinates, radius = $radius");
  our @vendermap;
  my $pos = calcPosition($char);
  my ($randX, $randY, $realrandX, $realrandY);
  for (my $try = 0; $try <= $::config{autoshop_tries}; $try++) {
    $randX = $maxRad + $radius - int(rand(($radius*2)+1));
    $randY = $maxRad + $radius - int(rand(($radius*2)+1));
    if ($vendermap[$randX][$randY] > $::config{autoshop_maxweight}) {
      debug(sprintf("calculated mapcoords (%d %d) have weight %d, retrying (try %d/%d)",
            $randX, $randY, $vendermap[$randX][$randY], $try, $::config{autoshop_tries}));
    } else {
      if ($randX >= $maxRad) {$realrandX = ($pos->{x})+($randX)-$maxRad} else {$realrandX = ($pos->{x})-$maxRad+($randX)};
      if ($randY >= $maxRad) {$realrandY = ($pos->{y})+($randY)-$maxRad} else {$realrandY = ($pos->{y})-$maxRad+($randY)};
      if (!checkFieldWalkable(\%field, $realrandX, $realrandY)) {
        debug(sprintf("calculated coords (%d %d) are non-walkable, retrying (try %d/%d)",
           $realrandX, $realrandY, $try, $::config{autoshop_tries}));
      } else {
        return($realrandX, $realrandY, 1)
      };
    };
  };
  if ($radius == $maxRad) {
    warning "Could not find free coordinates. Giving up.";
    return(0,0,0);
  } else {
    return(suggest($radius*2));
  };
};

# when called, this function checks whether we are on an already occupied field
# or a field with a weight > maxweight. If so, selects new coordinates and calls
# walk_and_recheck. If not, open shop.
sub autoshop {
  if ($conState < 5) {
    $timeout{ai_autoshop}{time} = time;
    $timeout{ai_shop}{time} = time;
  };
  if ($::config{autoshop} && AI::isIdle && $conState == 5 && timeOut($timeout{ai_autoshop}) &&
      !$shopstarted && !$char->{muted} && !$char->{sitting}) {
    clearVendermap(); buildVendermap();
    our @vendermap;
    if ($vendermap[$maxRad][$maxRad] > $::config{autoshop_maxweight}) {
      debug("This place's weight is $vendermap[$maxRad][$maxRad]. Moving.");
      my ($x, $y, $success) = suggest($::config{autoshop_radius});
      walkto($x, $y) if ($success);
    } elsif (timeOut($timeout{ai_shop})) {::openShop(); return};
    $timeout{ai_autoshop}{time} = time;
  };
  if ($::config{autoshop} && !AI::isIdle && !$shopstarted) {
    $timeout{ai_shop}{time} = time;
  };
};

# for those who are interested: dump the map to a file
sub showmap {
  clearVendermap(); buildVendermap();
  our @vendermap;
  my $pos = calcPosition($char);
  open SHOPMAP, "> $Settings::logs_folder/shopmap.txt";
  for (my $y = $maxRad*2; $y > 0; $y--) {
    my $line; my ($realX, $realY);
    if ($y >= $maxRad) { $realY = ($pos->{y})+($y)-$maxRad; } else {$realY = ($pos->{y})-$maxRad+($y)};
    for (my $x = 0; $x <= $maxRad*2; $x++) {
      if ($x >= $maxRad) { $realX = ($pos->{x})+($x)-$maxRad; } else {$realX = ($pos->{x})-$maxRad+($x)};
      if ($x == $maxRad && $y == $maxRad) {$line .= "X"}
      else {
         if (!checkFieldWalkable(\%field, $realX, $realY)) {$line .= "#"}
         elsif ($vendermap[$x][$y] == 0)                   {$line .= " "}
         else                 {$line .= sprintf("%X",$vendermap[$x][$y])};
      };
    };
    $line .= "\n";
    print SHOPMAP $line;
  };
  close SHOPMAP;
  message "wrote shopmap.\n", "list";
};

# adds the shop environment of a vendor to the map
sub addToVendermap {
  my ($posX, $posY, $type, $realX, $realY) = @_;
  return if (!$posX);
  if ($posX < 0 || $posY < 0) {
    error "[autoshop] Player $type ($realX $realY) out of array ($posX $posY)\n";
    return;
  };

  our @vendermap;
  if ($type eq 'player') {$vendermap[$posX][$posY] += 5; return};

  for (my $a = 0; $a < 3; $a++) {
    $vendermap[$posX+$a-3][$posY] += $a+1 if ($posX+$a-3 >= 0);
    $vendermap[$posX-$a+3][$posY] += $a+1 if ($posX-$a+3 <= 30);
    $vendermap[$posX][$posY+$a-3] += $a+1 if ($posX+$a-3 >= 0);
    $vendermap[$posX][$posY-$a+3] += $a+1 if ($posX-$a+3 <= 30);
  };

  $vendermap[$posX+1][$posY+1] += 2;
  $vendermap[$posX+1][$posY+2] += 1;
  $vendermap[$posX+2][$posY+1] += 1;

  if ($posX >= 1) {
    $vendermap[$posX-1][$posY+1] += 2;
    $vendermap[$posX-1][$posY+2] += 1;
    if ($posX >= 2) {$vendermap[$posX-2][$posY+1] += 1};
  };

  if ($posY >= 1) {
    $vendermap[$posX+1][$posY-1] += 2;
    $vendermap[$posX+2][$posY-1] += 1;
    if ($posY >= 2) {$vendermap[$posX+1][$posY-2] += 1};
  };

  if ($posX >= 1 && $posY >= 1) {
    $vendermap[$posX-1][$posY-1] += 2;
    if ($posY >= 2) {$vendermap[$posX-1][$posY-2] += 1};
    if ($posX >= 2) {$vendermap[$posX-2][$posY-1] += 1};
  };
};

# scans for players / vendors and builds the map
sub buildVendermap {
  my $arr = shift;
  if (!$arr) {
    buildVendermap(\@::venderListsID);
    refreshChatRooms();
    buildVendermap(\@chtRooms);
    buildVendermap(\@::playersID);
    return;
  };

  my $pos = calcPosition($char);

  for (my $i = 0; $i < @{$arr}; $i++) {
    my $player;
    next if (!$$arr[$i]);
    $player = $players{$$arr[$i]};
    next if ($player->{pos_to}{x} == 0);

    my ($newX, $newY);
    if ($pos->{x} >= $player->{pos_to}{x}) {$newX = $maxRad - ($pos->{x}) + ($player->{pos_to}{x})}
    else                                   {$newX = $maxRad + ($player->{pos_to}{x}) - ($pos->{x})};
    if ($pos->{y} >= $player->{pos_to}{y}) {$newY = $maxRad - ($pos->{y}) + ($player->{pos_to}{y})}
    else                                   {$newY = $maxRad + ($player->{pos_to}{y}) - ($pos->{y})};

    if ($arr == \@::playersID) {addToVendermap($newX, $newY, 'player', $player->{pos_to}{x}, $player->{pos_to}{y})}
    else {addToVendermap($newX, $newY, 'vender', $player->{pos_to}{x}, $player->{pos_to}{y})};
  };
};

sub clearVendermap {
  our @vendermap = ();
  for (my $x = 0; $x <= $maxRad*2; $x++) {
    for (my $y = 0; $y <= $maxRad*2; $y++) {$vendermap[$x][$y] = 0};
  };
};
          
sub refreshChatRooms {
  for (my $i = 0; $i < @::chatRoomsID; $i++) {
     push(@chtRooms, $::chatRooms{$::chatRoomsID[$i]}{'ownerID'});
  };
};

return 1;
