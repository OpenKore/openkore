package Writer;

use strict;
use warnings;
use FindBin;
use Extractor;
use Utils;
use CGI qw(escapeHTML);


sub error {
	print STDERR "** Error: @_";
}

sub makeupText {
	my $text = shift;

	sub list {
		my $text = shift;
		my @list = split(/\n+- /, $text);
		foreach (@list) {
			$_ = "<li>$_</li>";
		}
		$text = join("\n", @list);
		$text =~ s/<li><\/li>//sg;
		return "<ul>$text\n</ul>";
	}
	sub preformatted {
		my ($attrs, $text) = @_;
		$attrs = '' if (!defined($attrs));
		# Remove auto-generated tags inside <pre> blocks.
		$text =~ s/\n<{p}>//sg;
		$text =~ s/<{.*?}>//sg;
		return "<pre${attrs}>" . Utils::syntaxHighlight($text) . "</pre>";
	}

	$text =~ s/\n\n/\n<{p}>\n\n/sg;
	$text =~ s/(<\/dd>)\n<{p}>(\n*<dt>)/$1$2/sg;
	$text =~ s/^`l$/<ul>/gm;
	$text =~ s/^`l`$/<\/ul>/gm;
	$text =~ s/<ul>(.*?)<\/ul>/&list($1)/gse;
	$text =~ s/(^| |\n)(http:\/\/.*?)($| |\n)/$1<a href="$2">$2<\/a>$3/gs;


	sub createFuncLink {
		my $func = shift;
		return '' if (!defined $func);

		my $name = $func;
		$name =~ s/\(\)$//;

		if ($Extractor::functions{$name}) {
			my $file = $Extractor::functions{$name}{package};
			$file =~ s/::/--/g;
			return "<a href=\"$file.html#$name\"><code>$func</code></a>";
		}
		return "<{code}>$func<{\/code}>";
	}
	sub linkModule {
		my $text = shift;
		my $package = $text;
		$package =~ s/\.pm$//;

		if ($Extractor::modules{$package}) {
			$package =~ s/::/--/g;
			$text = "<a href=\"${package}.html\">$text</a>";
		}
		return $text;
	}
	sub processModuleTag {
		my ($module) = @_;
		if ($Extractor::modules{$module}) {
			my $link = $module;
			$link =~ s/::/--/g;
			return "<a href=\"$link.html\"><code>$module</code></a>";
		} else {
			return "<code>$module</code>";
		}
	}
	sub processClassTag {
		return makeClassLink($_[0]);
	}

	# Links to modules/classes
	$text =~ s/([a-z0-9_:]+\.pm)/&linkModule($1)/gie;
	$text =~ s/\@MODULE\((.*?)\)/&processModuleTag($1)/gse;
	$text =~ s/\@CLASS\((.*?)\)/&processClassTag($1)/gse;
	# Functions
	$text =~ s/(\$?[a-z0-9_:\->]+\(\))/&createFuncLink($1)/gie;
	# Variables
	$text =~ s/(^|\n| )([\$\%\@][a-z0-9_{\'}:]+)/$1<{code}>$2<{\/code}>/gis;
	$text =~ s/(<pre( .*?)?>(.*?)<\/pre>)/&preformatted($2, $3)/gse;

	$text =~ s/<{(.*?)}>/<$1>/gs;
	return $text;
}

sub makeClassLink {
	my ($type) = @_;
	if ($type && $Extractor::classes{$type}) {
		my $package = $Extractor::classes{$type};
		$package =~ s/::/--/g;
		return "<a href=\"${package}.html\">" . escapeHTML($type) . "</a>";
	} else {
		return escapeHTML($type);
	}
}

sub parseDataType {
	my ($str) = @_;

	if ($str =~ /^(.+?)<(.+)>(.?)$/) {
		my ($a, $b, $c) = ($1, $2, $3);
		$str = makeClassLink($1) . '&lt;' . parseDataType($2) . '&gt;' . $3;
		return $str;
	} else {
		return makeClassLink($str);
	}
}

sub parseDeclarations {
	my ($decl) = @_;
	return "" if ($decl eq "");
	my @params;
	$decl =~ s/^\(//;
	$decl =~ s/\)$//;

	foreach my $param (split / +, +/, $decl) {
		# Check whether this parameter has a type definition
		if ($param =~ / /) {
			my ($type, $name) = split / /, $param, 2;
			$type = parseDataType($type);
			push @params, "<span class=\"type\">$type</span> " . escapeHTML($name);
		} else {
			push @params, escapeHTML($param);
		}
	}
	return "(" . join(', ', @params) . ")";
}


sub writeModuleHTML {
	my $module = shift;

	if (! -d 'srcdoc' && !mkdir('srcdoc')) {
		error "Unable to create folder 'srcdoc'\n";
		exit 1;
	}

	my $htmlFile = $module->{package};
	$htmlFile =~ s/::/--/g;
	$module->{htmlFile} = "$htmlFile.html";
	$htmlFile = "srcdoc/$htmlFile.html";

	my ($html, $f);
	if (!open($f, "< $FindBin::Bin/data/template.html")) {
		error "Unable to open template $FindBin::Bin/data/template.html\n";
		return 0;
	}
	local($/);
	$html = <$f>;
	close($f);


	if (!open(F, "> $htmlFile")) {
		error "Unable to open $htmlFile for writing.\n";
		return 0;
	}

	my $description = makeupText($module->{desc});
	$html =~ s/\@TITLE\@/$module->{package} - $module->{name}/g;
	$html =~ s/\@DESCRIPTION\@/$description/;
	$html =~ s/\@MODIFIED\@/gmtime/ge;
	$html =~ s/\@MODULE\@/$module->{package}/g;


	sub writeFunctionIndex {
		my $module = shift;
		my $category = shift;
		my $text = '';

		foreach my $itemName (sort(keys %{$module->{categories}{$category}})) {
			my $item = $module->{categories}{$category}{$itemName};
			my $name = $item->{name};
			my $abstract = $item->{abstract} ? "abstract&nbsp;" : "";
			my $returnType = parseDataType($item->{type} || "");
			my $decl = parseDeclarations($item->{param_declaration});

			$text .= "<tr onclick=\"location.href='#$item->{name}';\">\n" .
				"	<td class=\"return-type\">$abstract$returnType</td>\n" .
				"	<td class=\"func\">" .
					"<a href=\"#$item->{name}\">$name</a>" .
					"</td>\n" .
				"	<td class=\"decl\">$decl</td>\n" .
				"</tr>";
		}

		if ($text ne '') {
			my $title = ($category eq "") ? "Functions in this module" : $category;
			$text = "<p><table class=\"functionIndex\">\n" .
				"<tr><th colspan=\"3\">$title</th></tr>" .
				"$text\n" .
				"</table>\n";
		}
		return $text;
	}
	sub writeFunctionIndices {
		my $module = shift;
		my $text = '';
		foreach my $category (sort(keys %{$module->{categories}})) {
			$text .= writeFunctionIndex($module, $category);
		}
		return $text;
	}
	$html =~ s/\@FUNCINDEX\@/&writeFunctionIndices($module)/ge;


	sub writeFunctionTable {
		my $module = shift;
		my $text = '';
		my $first = 1;

		foreach my $itemName (sort(keys %{$module->{items}})) {
			my $func = $module->{items}{$itemName};
			my $returnType = parseDataType($func->{type} || "");
			my $abstract = $func->{abstract} ? "abstract " : "";
			my $decl = parseDeclarations($func->{param_declaration});
			my $funcName = escapeHTML($func->{name});

			$text .= "<p><hr class=\"function_sep\">" if (!$first);
			$first = 0;

			$text .= "<p>\n<div class=\"function\">" .
				"<a name=\"$funcName\"></a>\n" .
				"<h3>$funcName</h3>\n" .
				"<dl>\n\t<dt class=\"decl\">\n" .
					"\t\t<span class=\"return-type\">$abstract $returnType</span>" .
					(($returnType eq "") ? "" : " ") .
					"<strong>$funcName</strong>" .
					"$decl\n" .
				"\t</dt>\n" .
				"\t<dd>\n";

			my $write_bluelist = 0;
			if (@{$func->{params}} || $func->{returns} ne '' ||
			    $func->{requires} ne '' || $func->{ensures} ne '' ||
			    $func->{invariant} ne '' || $func->{throws} ne '') {
				$write_bluelist = 1;
				$text .= "\t\t<dl class=\"params_and_returns\">\n";
			}

			if (@{$func->{params}}) {
				$text .= "\t\t<dt class=\"params\"><strong>Parameters:</strong></dt>\n";
				foreach my $param (@{$func->{params}}) {
					my $desc = makeupText($param->[1]);
					$text .= "\t\t\t<dd class=\"param\"><code>" . $param->[0] . "</code> : $desc</dd>\n";
				}
			}

			if ($func->{requires} ne '') {
				$text .= "\t\t<dt class=\"requires\"><strong>Requires:</strong></dt>\n" .
					"\t\t\t<dd class=\"requires\">" . $func->{requires} . "</dd>\n";
			}
			if ($func->{ensures} ne '') {
				$text .= "\t\t<dt class=\"ensures\"><strong>Ensures:</strong></dt>\n" .
					 "\t\t\t<dd class=\"ensures\">" . makeupText($func->{ensures})
					 . "</dd>\n";
			}
			if ($func->{returns} ne '') {
				$text .= "\t\t<dt class=\"returns\"><strong>Returns:</strong></dt>\n" .
					"\t\t\t<dd class=\"returns\">" . $func->{returns} . "</dd>\n";
			}
			if ($func->{invariant} ne '') {
				$text .= "\t\t<dt class=\"invariant\"><strong>Invariant:</strong></dt>\n" .
					 "\t\t\t<dd class=\"invariant\">" . makeupText($func->{invariant})
					 . "</dd>\n";
			}
			if ($func->{throws} ne '') {
				$text .= "\t\t<dt class=\"throws\"><strong>Throws:</strong></dt>\n" .
					 "\t\t\t<dd class=\"throws\">" . makeupText($func->{throws})
					 . "</dd>\n";
			}

			if ($write_bluelist) {
				$text .= "\t\t</dl><p>\n\n";
			}

			$text .= "\t\t<div class=\"desc\">" . makeupText($func->{desc}) . "</div>\n";

			if ($func->{example} ne '') {
				my $example = $func->{example};
				$text .= "\n\t\t<dl class=\"example\">\n" .
					"\t\t\t<dt><strong>Example:</strong></dt>\n" .
					"\t\t\t<dd><pre>";
				$text .= Utils::syntaxHighlight($example);
				$text .= "</pre></dd>\n\t\t</dl>\n";
			}

			$text .= "\t</dd>\n</dl>\n</div>\n\n\n";
		}

		if ($text ne '') {
			$text = "<p><hr class=\"details_sep\">\n\n" .
				"<h2>Details</h2>\n" .
				"<div class=\"details\">\n\n\n" .
				"$text\n\n\n" .
				"</div>";
		}
		return $text;
	}

	$html =~ s/\@FUNCTABLE\@/&writeFunctionTable($module)/ge;

	print F $html;
	close(F);
}

1;
