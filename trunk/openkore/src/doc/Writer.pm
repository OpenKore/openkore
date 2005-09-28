package Writer;

use strict;
use warnings;
use FindBin;
use Extractor;


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
	sub preformatted {
		my $text = shift;
		# Remove auto-generated tags inside <pre> blocks.
		$text =~ s/\n<{.*?}>//sg;
		return $text;
	}

	$text =~ s/\n\n/\n<{p}>\n\n/sg;
	$text =~ s/(<\/dd>)\n<{p}>(\n*<dt>)/$1$2/sg;
	$text =~ s/^`l$/<ul>/gm;
	$text =~ s/^`l`$/<\/ul>/gm;
	$text =~ s/<ul>(.*?)<\/ul>/&list($1)/gse;
	$text =~ s/(^| |\n)(http:\/\/.*?)($| |\n)/$1<a href="$2">$2<\/a>$3/gs;
	$text =~ s/(<pre( .*?)?>.*?<\/pre>)/&preformatted($1)/gse;


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

	# Functions
	$text =~ s/(\$?[a-z0-9_:\->]+\(\))/&createFuncLink($1)/gie;
	# Variables
	$text =~ s/(^|\n| )([\$\%\@][a-z0-9_{\'}:]+)/$1<{code}>$2<{\/code}>/gis;
	# Links to modules
	$text =~ s/([a-z0-9_:]+\.pm)/&linkModule($1)/gie;

	$text =~ s/<{(.*?)}>/<$1>/gs;
	return $text;
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
			$text .= "<tr onclick=\"location.href='#$item->{name}';\">\n\t<td class=\"func\"><code>" .
				"<a href=\"#$item->{name}\">$item->{name}</a>" .
				"</code></td>\n" .
				"\t<td class=\"decl\"><code>" .
				$item->{param_declaration} .
				"</code></td>\n</tr>";
		}

		if ($text ne '') {
			my $title = ($category eq "") ? "Functions in this module" : $category;
			$text = "<p><h2>$title</h2>\n" .
				"<table class=\"functionIndex\">\n" .
				"<tr><th>Name</th><th>Parameters</th></tr>\n" .
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
			$text .= "<p><hr class=\"function_sep\">" if (!$first);
			$first = 0;

			$text .= "<p>\n<div class=\"function\">" .
				"<a name=\"$func->{name}\"></a>\n" .
				"<dl>\n\t<dt class=\"decl\"><code><strong>$func->{name}</strong>" .
				$func->{param_declaration} . "</code></dt>\n" .
				"\t<dd>\n";

			my $write_bluelist = 0;
			if (@{$func->{params}} || $func->{returns} ne '') {
				$write_bluelist = 1;
				$text .= "\t\t<dl class=\"params_and_returns\">\n";
			}

			if (@{$func->{params}}) {
				$text .= "\t\t<dt class=\"params\"><strong>Parameters:</strong></dt>\n";
				foreach my $param (@{$func->{params}}) {
					$text .= "\t\t\t<dd class=\"param\"><code>" . $param->[0] . "</code> : " . $param->[1] . "</dd>\n";
				}
			}

			if ($func->{returns} ne '') {
				$text .= "\t\t<dt class=\"returns\"><strong>Returns:</strong></dt>\n" .
					"\t\t\t<dd>" . $func->{returns} . "</dd>\n";
			}

			if ($write_bluelist) {
				$text .= "\t\t</dl><p>\n\n";
			}

			$text .= "\t\t<div class=\"desc\">" . makeupText($func->{desc}) . "</div>\n";

			if ($func->{example} ne '') {
				my $example = $func->{example};
				$example =~ s/(#.*)/<i class="comment">$1<\/i>/mg;

				$text .= "\n\t\t<dl class=\"example\">\n" .
					"\t\t\t<dt><strong>Example</strong>:</dt>\n" .
					"\t\t\t<dd><pre>";
				$text .= $example;
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
