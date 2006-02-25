#!/usr/bin/perl 

#use strict; 
use warnings; 

################ 
#The origanal MapView was not writen by me, I have made some cosmetic and usability changes, but the core code is not mine. 
# - VT200 
#
#Added potions to display hp/sp/name/level
#

use Tk; 

#start VT's newcode 
my ($maxx, $maxy); 

my $repeat_id; 
my $repeat_time = 1; 
my $last_map = ''; 
my $bitmap_id; 
my $oval_id; 

my $main = new MainWindow; 
my $frame = $main->Frame()->pack( 
   -side => 'top', 
   -expand => 1, 
   -fill => 'x', 
); 
$frame->Button( 
   -text =>"Refresh" , 
   -command=> [\&windowwrite] 
)->pack( 
   -side => 'left', 
); 
$frame->Label( 
   -anchor => 'e', 
   -text => 'Auto Refresh Time: ', 
)->pack( 
   -side => 'left', 
   -expand => 1, 
   -fill => 'x', 
); 
my $entry = $frame->Entry( 
   -width => 4, 
   -textvariable => \$repeat_time, 
   -validate => 'key', 
   -validatecommand => sub { my $tmp = shift; return $tmp =~ /^\d*$/ } 
)->pack( 
   -side => 'left' 
); 
my $start = $frame->Button( 
   -text => "Start", 
   -command=> [\&start_repeat] 
)->pack( 
   -side => 'left' 
); 
my $stop = $frame->Button( 
   -text => "Stop", 
   -command=> [\&stop_repeat] 
)->pack( 
   -side => 'left' 
); 


my $canvas = $main->Canvas( 
   -width =>100, 
   -height =>100, 
   -background => 'white' 
)->pack( 
   -side => 'top' 
); 

my $status_frame = $main->Frame( 
)->pack( 
   -side => 'bottom', 
   -expand => 1, 
   -fill => 'x', 
); 
my $status_gen = $status_frame->Label( 
   -anchor => 'w', 
   -text => 'Ready', 
   -relief => 'sunken', 
)->pack( 
   -side => 'left', 
   -expand => 1, 
   -fill => 'x', 
); 
my $status_posx = $status_frame->Label( 
   -text => '0', 
   -width => 4, 
   -relief => 'sunken', 
)->pack( 
   -side => 'left', 
); 
my $status_posy = $status_frame->Label( 
   -text => '0', 
   -width => 4, 
   -relief => 'sunken', 
)->pack( 
   -side => 'left' 
); 
my $status_mousex = $status_frame->Label( 
   -text => '0', 
   -width => 4, 
   -relief => 'sunken', 
)->pack( 
   -side => 'left', 
); 
my $status_mousey = $status_frame->Label( 
   -text => '0', 
   -width => 4, 
   -relief => 'sunken', 
)->pack( 
   -side => 'left' 
); 
my $status_auto = $status_frame->Label( 
   -text => 'off', 
   -width => 4, 
   -relief => 'sunken', 
)->pack( 
   -side => 'right', 
); 
#end VT's newcode 
# junq start
my $info_frame = $main->Frame( 
)->pack( 
   -side => 'bottom', 
   -expand => 1, 
   -fill => 'x', 
); 
my $status_name = $info_frame->Label(
   -text => "Name",
   -relief => 'sunken',
)->pack( 
   -expand => 1,
   -side => 'left', 
   -fill => 'x',
);

my $status_bs = $info_frame->Label(
   -text => "Base",
   -width => 10,
   -relief => 'sunken',
)->pack( 
   -side => 'left', 
);
my $status_jl = $info_frame->Label(
   -text => "Job",
   -width => 10,
   -relief => 'sunken',
)->pack( 
   -side => 'left', 
);
my $status_hp = $info_frame->Label(
   -text => "HP",
   -width => 10,
   -relief => 'sunken',
)->pack( 
   -side => 'left', 
); 
my $status_sp = $info_frame->Label(
   -text => "SP",
   -width => 10,
   -relief => 'sunken',
)->pack( 
   -side => 'left', 
); 

# junq end
MainLoop(); 

sub windowwrite{ 
#start VT's newcode 
   $status_gen->configure( -text => 'Refreshing' ); 
   $status_gen->update(); 
#end VT's newcode 
### Sraet Move 
  $canvas->delete($oval_id) if $oval_id; 
  foreach (@ovals) { 
    $canvas->delete($_); 
  } 
### 
     unless (open (DATA,'<walk.dat')) { 
      $status_gen->configure( -text => "error opening walk.dat: $!" ); 
      warn "error opening walk.dat: $!"; 
      return; 
   } 
     my $map = <DATA>; 
   chomp($map);   #VT 
     my $x = <DATA>; 
   chomp($x);   #VT 
     my $y = <DATA>; 
   chomp($y);   #VT 
### Sraet Addon Start 
  my $i = 0; 
  my $j = 0; 
  my $k = 0; 
  my @ml = (); 
  my @nl = (); 
  my @pl = (); 
  my @mob = (); 
### junq start
  my @hp = ();
  my @sp = ();
  my @bs = ();
  my @jl = ();
  my @name = ();
### junq end
  foreach(<DATA>) { 
    
    @mob = split(/ /, $_); 
    if ($mob[0] eq "ML") {$ml[$i] = $mob[1]; $ml[$i+1] = $mob[2]; $i += 2; } 
    if ($mob[0] eq "NL") {$nl[$j] = $mob[1]; $nl[$j+1] = $mob[2]; $j += 2; } 
    if ($mob[0] eq "PL") {$pl[$k] = $mob[1]; $pl[$k+1] = $mob[2]; $k += 2; } 
### junq start    
    if ($mob[0] eq "HP") {$hp[0] = $mob[1]; }
    if ($mob[0] eq "SP") {$sp[0] = $mob[1]; }
    if ($mob[0] eq "NAME") 
    {
	$name[0] = '';
    	for (my $pos = 1;$pos<scalar(@mob);$pos++)
    	{
    		$name[0] .= $mob[$pos];
    	}
    }
    if ($mob[0] eq "BS") {$bs[0] = $mob[1]; }
    if ($mob[0] eq "JL") {$jl[0] = $mob[1]; }
### junq end
  } 
  $i = ($i > 0) ? $i - 1 : $i; 
  $j = ($j > 0) ? $j - 1 : $j; 
  $k = ($k > 0) ? $k - 1 : $k; 
  
### junq start
  my $len;
  my $msg;
  ## hp
  $msg = "HP: $hp[0]";
  $len = length($msg);
  $msg =~ s/\n//g;
  $status_hp->configure( -text => "$msg", -width=>$len );
  $status_hp->update();
  ## sp
  $msg = "SP: $sp[0]";
  $len = length($msg);
  $msg =~ s/\n//g;
  $status_sp->configure( -text => "$msg", -width=>$len );
  $status_sp->update();
  ## baselevel
  $msg = "Base: $bs[0]";
  $len = length($msg);
  $msg =~ s/\n//g;
  $status_bs->configure( -text => "$msg", -width=>$len );
  $status_bs->update();
  ## joblevel
  $msg = "Job: $jl[0]";
  $len = length($msg);
  $msg =~ s/\n//g;
  $status_jl->configure( -text => "$msg", -width=>$len );
  $status_jl->update();  
  ## name
  $msg = "$name[0]";
  $len = length($msg);
  $msg =~ s/\n//g;
  $status_name->configure( -text => "$msg", -width=>$len );
  $status_name->update();  
   
### junq end  
### Sraet Addon End 
     close(DATA); 
     $map = ($map eq "") ? "map/no_map.xbm" : "map/" . $map . ".xbm"; 
#blueviper22      
#$map=<DATA>;$map=~s/[\r\n]//;$x=<DATA>;$y=<DATA>;$map='map/'.$map.'.xbm'; 
#start VT's newcode 
   if ($map && $map ne $last_map) { 
      $last_map = $map; 
        $maxx = 0; 
        $maxy = 0; 
        open (DATA, "< $map"); 
        foreach(<DATA>){ 
             if ($_ =~ /^\#define data_width ([0-9]*)/) { 
                  $maxx = $1; 
             } 
             if ($_ =~ /^\#define data_height ([0-9]*)/) { 
                  $maxy = $1; 
             } 
             if (($maxx >0) && ($maxy >0)) { 
                  last; 
             } 
        } 
        close(DATA); 


      $canvas->configure( 
         -width => $maxx, 
         -height => $maxy 
      ); 
      $canvas->delete($bitmap_id) if $bitmap_id; 
      #$bitmap_id = $canvas->createBitmap( 
      #   $maxx / 2, 
      #   $maxy / 2, 
      #   -bitmap => "\@$map" 
      #); 
      $bitmap_id = $canvas->createBitmap( 
      #   $maxx / 2, 
      #   $maxy / 2, 
         2, 
         2, 
         -bitmap => "\@$map", 
         -anchor => 'nw', 
      ); 
      $canvas->bind($bitmap_id, '<Motion>', [\&pointchk , Ev('x') , Ev('y')]); 
   } 
### Sraet Addon Start 
   while($i > 0 || $j > 0 || $k > 0) { 
      if ($i > 0) { $ovals[@ovals] = $canvas->createOval(($ml[$i-1]-1),($maxy-$ml[$i]+1),($ml[$i-1]+1),($maxy-$ml[$i]-1),-width=>4 ,-outline=>"red");    $i -= 2; } 
      if ($j > 0) { $ovals[@ovals] = $canvas->createOval(($nl[$j-1]-1),($maxy-$nl[$j]+1),($nl[$j-1]+1),($maxy-$nl[$j]-1),-width=>4 ,-outline=>"yellow"); $j -= 2; } 
      if ($k > 0) { $ovals[@ovals] = $canvas->createOval(($pl[$k-1]-1),($maxy-$pl[$k]+1),($pl[$k-1]+1),($maxy-$pl[$k]-1),-width=>4 ,-outline=>"green");  $k -= 2; } 
   } 
### Sraet Addon End 
   $oval_id = $canvas->createOval( 
      $x - 1, 
      $maxy - $y + 1, 
      $x + 1, 
      $maxy - $y - 1, 
      -width => 4, 
      -outline => "blue" 
   ) if ($map ne ""); 
   $status_posx->configure( -text => $x ); 
   $status_posy->configure( -text => $y ); 

   $status_gen->configure( -text => 'Ready' ); 
   $status_gen->update(); 
#end VT's newcode 
} 

##### 
sub pointchk{ 
#start VT's newcode 
   $status_mousex->configure( -text => $_[1] ); 
   $status_mousey->configure( -text => $maxy - $_[2] ); 
#end VT's newcode 
} 


#start VT's newcode 
sub repeat { 
   windowwrite(); 
   my $delay = $repeat_time ? $repeat_time * 1000 : 1000; 
   $repeat_id = $main->after($delay , [\&repeat]); 
#   print "delay: $delay\r"; 
} 

sub start_repeat { 
   $repeat_id->cancel if defined $repeat_id; 
   repeat(); 
   $status_auto->configure( -text => 'on' ); 
} 

sub stop_repeat { 
   $repeat_id->cancel if defined $repeat_id; 
   $repeat_id = undef; 
   $status_auto->configure( -text => 'off' ); 
} 
#end VT's newcode
