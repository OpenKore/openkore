#!/usr/bin/perl
use strict;
use warnings;
use feature qw(say);

# Introduction...
my (@sql, $id, $nome);	my $idUnique = 0;
push (@sql, "INSERT INTO `card_prefix` (`id`, `textPrefix`) VALUES \n");

# Start reading "cardprefixnametable.txt"
open(my $arq,'+<cardprefixnametable.txt') || die "$!\n";

while (<$arq>) {
    chomp;
	if ($_ ne '') {
		$idUnique++;
		if (substr($_, -1) eq '#') {
			($id, $nome) = /^([\w]+)\#(.+)#$/;
		} else {
			($id, $nome) = /^([\w]+)\#(.+)$/;
		}
		push (@sql, "($id, \"$nome\"),\n");
	}
}

substr($sql[$idUnique], -2) = ';';
close($arq);

# Save SQL
open my $fileSQL,">". 'cardprefixnametable.sql' or die "Cannot create file item_db.sql: $!";
print $fileSQL @sql;
close $fileSQL;