#!/usr/bin/env perl
# Documentation extractor. Extracts documentation from comments from .pm files and put them in HTML files.

use strict;
use warnings;
use File::Spec;
use FindBin;


our %modules = ();
our @modulesList = ();


foreach my $file (@ARGV) {
	extractFromFile($file);
}
writeDocumentation();
writeContentTable();


############################
## FUNCTIONS
############################


sub error {
	print STDERR "** Error: @_";
}

sub copyFile {
	my $file = shift;
	my $target = shift;

	if (!open(F, "< $file")) {
		error "Unable to copy file $file\n";
		exit 1;
	} else {
		binmode(F);
		my @lines = <F>;
		close(F);
		open(F, "> $target");
		binmode(F);
		print F join('', @lines);
		close(F);
	}
}

sub makeupText {
	my $text = shift;

	sub list {
		my $text = shift;
		#$text =~ s/^- /<\/li>\n<li>/gm;
		#$text =~ s/^[\n\w]<\/li>//s;
		#$text =~ s/(^|\n+)- (.*?)($|\n- )/<li>$2<\/li>\n- /gs;
		my @list = split(/\n+- /, $text);
		foreach (@list) {
			$_ = "<li>$_</li>";
		}
		$text = join("\n", @list);
		$text =~ s/<li><\/li>//sg;
		return "<ul>$text\n</ul>";
	}
	sub linkModule {
		my $module = shift;
		if (defined $modules{$module} && %{$modules{$module}}) {
			my ($link) = $module =~ /(.*?)(\.pm)?$/;
			$module = "<a href=\"$link.html\">$module</a>";
		}
		return $module;
	}

	$text =~ s/\n\n/\n<p>\n\n/sg;
	$text =~ s/^`l$/<ul>/gm;
	$text =~ s/^`l`$/<\/ul>/gm;
	$text =~ s/<ul>(.*?)<\/ul>/&list($1)/gse;


	sub createFuncLink {
		my $func = $_[0];
		return '' if (!defined $func);

		my $name = $func;
		$name =~ s/\(\)$//;

		foreach my $mod (@modulesList) {
			if ($modules{$mod}{functions}{$name}) {
				my ($file) = $mod =~ /(.*?)(\.pm)?$/;
				return "<a href=\"$file.html#$name\"><code>$func</code></a>";
			}
		}
		return "<code>$func<\/code>";
	}

	# Functions
	$text =~ s/([a-z0-9_:\->]+\(\))/&createFuncLink($1)/gie;
	# Variables
	$text =~ s/(\$[a-z0-9_{\'}:]+)/<code>$1<\/code>/gi;
	# Links to modules
	$text =~ s/([a-z0-9_:]+\.pm)/&linkModule($1)/gie;
	return $text;
}

# Extract documentation from .pm file and put them in a variable.
sub extractFromFile {
	my $file = shift;
	my $basename = (File::Spec->splitpath($file))[2];

	my $linenum = 0;
	my $state = 'ready';
	my $module_name = $basename;
	my $module_desc = '';
	my $funcname = '';
	my $funcparam_declaration = '';
	my $funcreturns = '';
	my $funcdesc = '';
	my $funcexample = '';
	my @funcparams = ();

	if (!open(F, "<$file")) {
		error "Unable to open $file for reading.\n";
		return 0;
	}
	binmode F;

	push @modulesList, $basename;
	$modules{$basename}{'name'} = $module_name;
	$modules{$basename}{'description'} = '';

	foreach my $line (<F>) {
		$linenum++;
		$line =~ s/\r//g;

		if (!($line =~ /^#/)) {
			if ($state eq 'module-description') {
				# The end of a module description has been reached
				$modules{$basename}{'name'} = $module_name;
				$modules{$basename}{'description'} = $module_desc;

			} elsif ($state =~ /^function-/ && $funcname ne '') {
				# The end of a function description has been reached
				my @funcparams_copy = @funcparams;
				$funcdesc =~ s/\n+$//s;
				$funcexample =~ s/\n+$//s;
				$modules{$basename}{'functions'}{$funcname}{'param_declaration'} = $funcparam_declaration;
				$modules{$basename}{'functions'}{$funcname}{'returns'} = $funcreturns;
				$modules{$basename}{'functions'}{$funcname}{'description'} = $funcdesc;
				$modules{$basename}{'functions'}{$funcname}{'parameters'} = \@funcparams_copy;
				$modules{$basename}{'functions'}{$funcname}{'example'} = $funcexample;
				push @{$modules{$basename}{'functionlist'}}, $funcname;
			}

			$module_desc = '';
			$funcname = '';
			$funcparam_declaration = '';
			$funcreturns = '';
			$funcdesc = '';
			@funcparams = ();
			$funcexample = '';
			$state = 'ready';
			next;
		}

		if ($state eq 'ready') {
			# Ready to accept the beginning of documentation comments.
			# Look for lines that start with '##'.
			$state = 'start' if ($line eq "##\n");

		} elsif ($state eq 'start') {
			# Reading first line of a documentation comment.
			if ($line =~ /^# MODULE DESCRIPTION: (.+)/) {
				# This comment block is a module description
				$module_name = $1 if ($1);
				$state = 'module-description';
			} else {
				# This is a function description
				($funcname, $funcparam_declaration) = $line =~ /^# ([a-z0-9_:\$\->]+) *(\(.*\))?/i;
				$funcparam_declaration = '' if (!defined $funcparam_declaration);
				$state = 'function-params';
			}

		} elsif ($state eq 'module-description') {
			$line =~ s/^# ?//;
			next if ($line eq "\n" && length($module_desc) == 0);
			$module_desc .= $line;

		} elsif ($state eq 'function-params') {
			$line =~ s/^# ?//;
			if ($line eq "\n") {
				# We have reached an empty line. This means there
				# are no parameter descriptions left to read.
				# The next line is the function description.
				$state = 'function-description';

				my $i = 0;
				foreach my $param (@funcparams) {
					if ($param->[0] eq 'Returns') {
						$funcreturns = $param->[1];
						delete $funcparams[$i];
						last;
					}
					$i++;
				}

			} else {
				# Process parameter
				$line =~ s/\n//;
				if (index($line, ':') == -1) {
					# A ':' character is missing.
					if (@funcparams == 0) {
						# This is an invalid parameter description.
						error "\"$line\" ($file line $linenum) is not a valid parameter description.\n";

					} else {
						# This is part of the previous parameter description.
						$funcparams[$#funcparams][1] .= $line;
					}
					next;
				}

				my ($param, $desc) = split(/ *: */, $line, 2);
				push @funcparams, [$param, $desc];
			}

		} elsif ($state eq 'function-description') {
			$line =~ s/^# ?//;
			next if ($line eq "\n" && length($funcdesc) == 0);

			if ($line eq "Example:\n") {
				$state = 'function-example';
				next;
			}
			$funcdesc .= $line;

		} elsif ($state eq 'function-example') {
			$line =~ s/^# ?//;
			$funcexample .= $line;
		}
	}
	close(F);
}

sub writeDocumentation {
	if (! -d 'srcdoc' && !mkdir('srcdoc')) {
		error "Unable to create folder 'srcdoc'\n";
		exit 1;
	}

	if (0 && open(F, "$FindBin::Bin/copylist.txt")) {
		foreach (<F>) {
			s/\n//;
			my $target = "$FindBin::Bin/srcdoc/" . (File::Spec->splitpath($_))[2];
			copyFile($_, $target);
		}
		close(F);
	}

	# Generate HTML
	foreach my $module (keys %modules) {
		my $modname = $module;
		($module) = $module =~ /(.*?)(\.pm)?$/;
		my $filename = "srcdoc/$module.html";
		my $html;

		if (!open(F, "< $FindBin::Bin/data/template.html")) {
			error "Unable to open template $FindBin::Bin/data/template.html\n";
			next;
		}
		$html = join('', <F>);
		close(F);

		if (!open(F, "> $filename")) {
			error "Unable to open $filename for writing.\n";
			next;
		}

		my $description = makeupText($modules{"$module.pm"}{'description'});
		$html =~ s/\@TITLE\@/$module.pm - $modules{"$module.pm"}{'name'}/g;
		$html =~ s/\@DESCRIPTION\@/$description/;
		$html =~ s/\@MODIFIED\@/gmtime/ge;
		$html =~ s/\@MODULE\@/$module.pm/g;

		sub writeFunctionIndex {
			my $module = shift;
			my $text = '';

			$module .= '.pm';
			return '' if (!$modules{$module}{'functionlist'} || !@{$modules{$module}{'functionlist'}});
			foreach my $function (sort @{$modules{$module}{'functionlist'}}) {
				$text .= "<tr onclick=\"location.href='#$function';\">\n\t<td class=\"func\"><code>" .
					"<a href=\"#$function\">$function</a>" .
					"</code></td>\n" .
					"\t<td class=\"decl\"><code>" .
					$modules{$module}{'functions'}{$function}{'param_declaration'} .
					"</code></td>\n</tr>";
			}

			if ($text) {
				$text = "<p><h2>Functions in this module</h2>\n" .
					"<table id=\"functionIndex\">\n" .
					"<tr><th>Name</th><th>Parameters</th></tr>\n" .
					"$text\n" .
					"</table>\n";
			}
			return $text;
		}
		$html =~ s/\@FUNCINDEX\@/&writeFunctionIndex($module)/ge;

		sub writeFunctionTable {
			my $text = '';
			my $module = shift;
			my $first = 1;

			$module .= '.pm';
			return '' if (!$modules{$module}{'functionlist'} || !@{$modules{$module}{'functionlist'}});
			foreach my $function (sort @{$modules{$module}{'functionlist'}}) {
					$text .= "<p><hr class=\"function_sep\">" if (!$first);
					$first = 0;

					$text .= "<p>\n<div class=\"function\">" .
						"<a name=\"$function\"></a>\n" .
						"<dl>\n\t<dt class=\"decl\"><code><strong>$function</strong>" .
						$modules{$module}{'functions'}{$function}{'param_declaration'} . "</code></dt>\n" .
						"\t<dd>\n";

					my $write_bluelist = 0;
					if (($modules{$module}{'functions'}{$function}{'parameters'}
					    && @{$modules{$module}{'functions'}{$function}{'parameters'}})
					    || $modules{$module}{'functions'}{$function}{'returns'} ne '') {
						$write_bluelist = 1;
						$text .= "\t\t<dl class=\"params_and_returns\">\n";
					}

					if ($modules{$module}{'functions'}{$function}{'parameters'}
					    && @{$modules{$module}{'functions'}{$function}{'parameters'}}) {
						$text .= "\t\t<dt class=\"params\"><strong>Parameters:</strong></dt>\n";
						foreach my $param (@{$modules{$module}{'functions'}{$function}{'parameters'}}) {
							$text .= "\t\t\t<dd class=\"param\"><code>" . $param->[0] . "</code> : " . $param->[1] . "</dd>\n";
						}
					}

					if ($modules{$module}{'functions'}{$function}{'returns'} ne '') {
						$text .= "\t\t<dt class=\"returns\"><strong>Returns:</strong></dt>\n" .
							"\t\t\t<dd>" . $modules{$module}{'functions'}{$function}{'returns'} . "</dd>\n";
					}

					if ($write_bluelist) {
						$text .= "\t\t</dl><p>\n\n";
					}

					$text .= "\t\t<div class=\"desc\">" .
						makeupText($modules{$module}{'functions'}{$function}{'description'}) . "</div>\n";

					if ($modules{$module}{'functions'}{$function}{'example'}
					 && $modules{$module}{'functions'}{$function}{'example'} ne '') {
						my $example = $modules{$module}{'functions'}{$function}{'example'};
						$example =~ s/(#.*)/<i class="comment">$1<\/i>/mg;

						$text .= "\n\t\t<dl class=\"example\">\n" .
							"\t\t\t<dt><strong>Example</strong>:</dt>\n" .
							"\t\t\t<dd><pre>";
						$text .= $example;
						$text .= "</pre></dd>\n\t\t</dl>\n";
					}

					$text .= "\t</dd>\n</dl>\n</div>\n\n\n";
			}

			if ($text) {
				$text = "<p><hr class=\"details_sep\">\n\n" .
					"<h2>Details</h2>\n" .
					"<div id=\"details\">\n\n\n" .
					"$text\n\n\n" .
					"</div>";
			}
			return $text;
		}
		$html =~ s/\@FUNCTABLE\@/&writeFunctionTable($module)/ge;

		print F $html;
		close(F);
	}
}


sub writeContentTable {
	my $html;

	if (!open(F, "< $FindBin::Bin/data/index-template.html")) {
		error "Unable to open $FindBin::Bin/data/index-template.html\n";
		exit 1;
	}
	$html = join('', <F>);
	close(F);

	sub writeModulesList {
		my $list;
		foreach my $module (@modulesList) {
			my ($file) = $module =~ /(.*?)(\.pm)?$/;
			$list .= "<tr onclick=\"location.href='$file.html';\">\n" .
				"\t<td class=\"moduleName\"><a href=\"$file.html\">$module</a></td>\n" .
				"\t<td class=\"moduleDesc\">$modules{$module}{'name'}</td>\n" .
				"</tr>";
		}
		return $list;
	}

	$html =~ s/\@MODIFIED\@/gmtime/ge;
	$html =~ s/\@MODULES\@/&writeModulesList()/ge;
	if (!open(F, "> srcdoc/index.html")) {
		error "Unable to write to srcdoc/index.html\n";
		exit 1;
	}
	print F $html;
	close(F);
}
