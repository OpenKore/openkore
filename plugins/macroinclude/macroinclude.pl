=pod
macroinclude - вкл-выкл директив !include в файле macros.txt
http://rofan.ru/viewtopic.php?f=27&t=8318
manticora

on/off !include in macros.txt
include off all - выключить (закомментировать) все директивы !include в macros.txt
include on Novice - включить все директивы, в которых есть строка Novice
include on Archer
include on vedro
include list - вывести список всех !include
после этого, естесственно, надо сделать reload macros.txt

include
Usage:
include on <filename or pattern>
include on all
include off <filename or pattern>
include off all
include list
include list

------on-------
!include ..\cfg_macros\Novice_1-Start.txt
!include ..\cfg_macros\Novice_2-Teachers.txt
!include ..\cfg_macros\Novice_3-ZoneSelect.txt
!include ..\cfg_macros\Novice_4-Tests.txt
!include ..\cfg_macros\Swordman_1-Quest.txt
!include ..\cfg_macros\Archer_1-Quest.txt
!include ..\cfg_macros\Thief_1-Quest.txt
!include ..\cfg_macros\Taekwon_1-Quest.txt
!include ..\cfg_macros\Merchant_1-Quest.txt
!include ..\cfg_macros\Acolyte_1-Quest.txt
!include ..\cfg_macros\Mage_1-Quest.txt
!include ..\cfg_macros\Ninja_1-Quest.txt
!include ..\cfg_macros\Gunslinger_1-Quest.txt
!include ..\cfg_macros\vedro.txt
!include ..\cfg_macros\Thief_2-Training.txt
!include ..\cfg_macros\Acolyte_2-Training.txt
!include ..\cfg_macros\Mage_2-Training.txt
!include ..\cfg_macros\Merchant_2-Training.txt
!include ..\cfg_macros\Archer_2-Training.txt
!include ..\cfg_macros\Swordman_2-Training.txt
!include autokach.mcs
!include ..\cfg_macros\Quest_1-SledyBoja.txt
!include ..\cfg_macros\Quest_2-Soki.txt
!include ..\cfg_macros\Quest_4-Diribabl.txt

------off------
include off Acoly
#!include ..\cfg_macros\Acolyte_1-Quest.txt
#!include ..\cfg_macros\Acolyte_2-Training.txt

=cut
package macroinclude;
use Plugins;
use Globals;
use Log qw(message);

Plugins::register('macroinclude','On-Off !include in macros.txt. manticora', \&Unload); 

my $chooks = Commands::register(['include', 'macros.txt, !include on/off', \&main]);
my @folders = Settings::getControlFolders();

sub Unload {
   Commands::unregister($chooks);
   message "macro include on off plugin unloading\n", 'success'
}

sub main {
	my ($cmd, $args) = @_;
	my ($key, $filename) = split(" ", $args);
	my @lines = ();
	my $needrewrite = 0;
	my $macro_file = (defined $config{macro_file})?$config{macro_file}:"macros.txt";
	my $macro = "";#Full name of macro-file

	foreach my $dir (@folders) {
		my $f = File::Spec->catfile($dir, $macro_file);
		if (-f $f) {
			$macro = $f;
			last;
		}
	}

	if ($macro eq "") {
		message "The macros.txt file is not found\nmacro plugin is not installed\nmacroinclude plugin dont work\n",'list';
		return 0;
	}

	open(my $fp,"<:utf8",$macro);	my @lines = <$fp>;	close($fp);
	if ($key eq 'list') {
		my $on = "\n------on-------\n";
		my $off = "\n------off------\n";
		foreach (@lines) {
			$on .= $_ if /^!include/;
			$off .= $_ if /^#[# ]*!include/;
		}	
		message "$on$off", 'list' ;
	} elsif ($key eq 'on') {
		if ($filename eq 'all') {
			foreach (@lines) {
				if (/^#[# ]*!include/) {
					$needrewrite = 1;
					s/^#[# ]*!/!/g;
					message "$_", 'list';
				}
			}
		} elsif ($filename) {
			foreach (@lines) {
				if (/^#[# ]*!include .*$filename.*/) {
					$needrewrite = 1;
					s/^#[# ]*!/!/g;
					message "$_", 'list';
				}
			} 
		} else { message "Usage: include on ( all | <filename> )\n",'list'}
	} elsif ($key eq 'off') {
		if ($filename eq 'all') {
			foreach (@lines) {
				if (/^!include/) {
					$needrewrite = 1;
					s/^!/#!/g;
					message "$_", 'list';
				}
			}
		} elsif ($filename)	{
			foreach (@lines) {
				if (/^!include .*$filename.*/) {
					$needrewrite = 1;
					s/^!/#!/g;
					message "$_", 'list';
				}
			}
		} else { message "Usage: include off ( all | <filename> )\n",'list'}
	} else {
		message "Usage:\n".
				"include on <filename or pattern>\n".
				"include on all\n".
				"include off <filename or pattern>\n".
				"include off all\n".
				"include list\n", 'list';
	}
	if ($needrewrite) { open ($fp,">:utf8",$macro); print $fp join ("", @lines); close($fp); }
	return 1;
}

return 1;