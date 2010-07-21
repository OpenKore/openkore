#on/off !include in macros.txt
#include off all - выключить (закомментировать) все директивы !include в macros.txt
#include on Novice - включить все директивы, в которых есть строка Novice
#include on Archer
#include on vedro
#include list - вывести список всех !include
package macroinclude;
use Plugins;
use Globals;
use Log qw(message error debug);

Plugins::register('macroinclude','On-Off !include in macros.txt. manticora', \&Unload); 

my $chooks = Commands::register(['include', 'macros.txt, !include on/off', \&main]);
my @folders = Settings::getControlFolders();
my $macrostxt = "$folders[0]\\macros.txt";

sub Unload {
   Commands::unregister($chooks);
   message "macro include on off plugin unloading\n", 'success'
}

sub main {
	my ($cmd, $args) = @_;
	my @new = ();
#	message "$args", 'list';
	my ($key, $filename) = split(" ", $args);
#	message "\n$key\n$filename\n----\n", 'list';
	if ($key eq 'list') {
		open(FILE,$macrostxt);
		my @lines = <FILE>;
		close(FILE);
		chomp @lines;
		message "\n------on-------\n", 'list';
		foreach my $line (@lines) {
			if ($line =~ /^!include/) {
				message "$line\n", 'list';
			}
		}
		message "\n------off------\n", 'list';
		foreach my $line (@lines) {
			if ($line =~ /^#([# ]*)!include/) {
				message "$line\n", 'list';
			}
		}
	} 
	elsif ($key eq 'on') {
#		message "on!!! $filename\n", 'list';
		if ($filename eq "all") {
			open(FILE,$macrostxt);
			my @lines = <FILE>;
			close(FILE);
			chomp @lines;
			foreach my $line (@lines) {
				if ($line =~ /^#([# ]*)!include/) {
					$line =~ s/^#([# ]*)!/!/g;
					message "$line\n", 'list';
				}
				push (@new, $line);
			}
			open (FILE,">$macrostxt");
			print FILE join ("\n", @new);
			close(FILE);
		} elsif ($filename) {
#		message "on!!! $filename\n", 'list';
			open(FILE,$macrostxt);
			my @lines = <FILE>;
			close(FILE);
			chomp @lines;
			foreach my $line (@lines) {
				if ($line =~ /^#([# ]*)!include .*$filename.*/) {
					$line =~ s/^#([# ]*)!/!/g;
					message "$line\n", 'list';
				}
				push (@new, $line);
			}
			open (FILE,">$macrostxt");
			print FILE join ("\n", @new);
			close(FILE);
		}
	} 
	elsif ($key eq 'off') {
		if ($filename eq "all") {
		message "=================all============\n", 'list';
			open(FILE,$macrostxt);
			my @lines = <FILE>;
			close(FILE);
			chomp @lines;
			foreach my $line (@lines) {
				if ($line =~ /^!include/) {
					$line =~ s/^!/#!/g;
					message "$line\n", 'list';
				}
				push (@new, $line);
			}
			open (FILE,">$macrostxt");
			print FILE join ("\n", @new);
			close(FILE);
			
		} elsif ($filename)	{
			#message "off!!!\n", 'list';
			open(FILE,$macrostxt);
			my @lines = <FILE>;
			close(FILE);
			chomp @lines;
			foreach my $line (@lines) {
				if ($line =~ /^!include .*$filename.*/) {
					$line =~ s/^!/#!/g;
					message "$line\n", 'list';
				}
				push (@new, $line);
			}
			open (FILE,">$macrostxt");
			print FILE join ("\n", @new);
			close(FILE);
		}
	}
	
}

#  filewrite($file, $key, $value)
## write FILE
#sub filewrite {
   # my ($file, $key, $value) = @_;

   # open (WRITE, ">$folders[0]/$file");
   # print WRITE join ("\n", @new);
   # close (WRITE);
#}
return 1;
