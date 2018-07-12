# macroinclude plugin by manticora
# Version 2.0 rewrited by Mortimal
# 
# Created for alljobs macro
# Last update 21.08.2017
# 
# on/off !include in macros.txt
# 
# Use config option:
# macroinclude macro
#
# Usage:
# include off all 
# include on Novice
# include on Archer
# include on vedro
# include list

package macroinclude;
use Plugins;
use Globals;
use Log qw(message error debug);

Plugins::register('macroinclude','On-Off !include in macros.txt. manticora', \&Unload); 

my $chooks = Commands::register(['include', 'macros.txt, !include on/off', \&main]);

sub Unload {
   Commands::unregister($chooks);
   message "Macroinclude plugin unloading.\n", 'success'
}

sub main {
	my ($cmd, $args) = @_;
	my ($key, $filename) = split(" ", $args);
	my $mcr;
	
	# Choose file block.
	if ($config{macroinclude} eq 'macro'){
		$mcr = $config{macro_file} || 'macros.txt';
	} else{
		if($config{macro_file}){
			$mcr = $config{macro_file};
		} else{
			$mcr = 'macros.txt';
		}
	}
	
	my $macro_file = Settings::getControlFilename($mcr);

	
	if ($macro_file eq "") {
		error "The macros.txt file is not found.".
			  "    Macroinclude plugin terminated.";
		return 0;
	}
	
	my @newlines;
	my $chng = 0;
	
	open(FILE,$macro_file);
	my @lines = <FILE>;
	close(FILE);
	chomp @lines;
	
	if($key eq ''
	   ||($key ne 'list'
		  && $key ne 'on'
		  && $key ne 'off'
		 )
	  )
	{
		error "Syntax Error in function include. Key not found.\n".
				"Usage: include <key> <filename or pattern>\n".
				"         include on <filename or pattern>\n".
				"         include on all\n".
				"         include off <filename or pattern>\n".
				"         include off all\n".
				"         include list\n";
	}
	elsif ($key eq 'list')
	{
		message "------------on-------------\n", 'list';
		foreach my $line (@lines)
		{
			if (my @file = $line =~ /^!include\s(.*)/)
			{
				message "$file[0]\n", 'list';
				$chng = 1;
			}
		}
		$chng?$chng = 0:0;
		message "------------off------------\n", 'list';
		foreach my $line (@lines)
		{
			if (my @file = $line =~ /^#.*!include\s(.*)/)
			{
				message "$file[0]\n", 'list';
				$chng = 1;
			}
		}
		$chng?$chng = 0:message "\n", 'list';
		message "---------------------------\n", 'list';
	} 
	else
	{
		if (!$filename)
		{
			error "Syntax Error in function include. Not found <filename or pattern>\n".
				"Usage: include on <filename or pattern>\n".
				"       include on all\n".
				"       include off <filename or pattern>\n".
				"       include off all\n".
				"       include list\n";
		}
		else
		{
			message "Changed:\n", 'list';
			foreach my $line (@lines)
			{
				if ($key eq 'on'
					&& $line =~ /^#.*!include/
					&& ($filename eq "all" 
						|| $line =~ /$filename/
					   )
				   )
				{
					$line =~ s/^#.*!/!/g;
					message "$line\n", 'list';
					$chng = 1;
				}
				elsif($key eq 'off' 
					  && $line =~ /^!include/
					  && ($filename eq "all" 
						  || $line =~ /$filename/
					     )
					 )
				{
					$line =~ s/^!/#!/g;
					message "$line\n", 'list';
					$chng = 1;
				}
				push (@newlines, $line);
			}
			if ($chng){
				open (FILE,">$macro_file");
				print FILE join ("\n", @newlines);
				close(FILE);
				Commands::run("reload $mcr");
			}
			else
			{
				message "--NONE--\n", 'list';
			}
		}
	}
}
return 1;
