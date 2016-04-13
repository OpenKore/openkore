#!/usr/bin/perl
use strict;
use warnings;
use feature qw(say);

sub ren() {
    return((rename($_[0],$_[1])) ? 1 : 0);
}

open(my $arq,'+<idnum2itemresnametable.txt') || die '$!\n';
while(<$arq>) {
    chomp;
    my($n, $v) = /^(\d+)#(.+)#$/;
	if ($n) {
		say((&ren('data/sprite/악세사리/남/남_' . $v . '.act','data/sprite/악세사리/남/M' . $n . '.act')) ? '[+] data/sprite/악세사리/남/남_' . $v . ' was successfully renamed to data/sprite/악세사리/남/M' . $n : '[!] Error renaming file data/sprite/악세사리/남/남_' . $v);
		say((&ren('data/sprite/악세사리/남/남_' . $v . '.spr','data/sprite/악세사리/남/M' . $n . '.spr')) ? '[+] data/sprite/악세사리/남/남_' . $v . ' was successfully renamed to data/sprite/악세사리/남/M' . $n : '[!] Error renaming file data/sprite/악세사리/남/남_' . $v);
		say((&ren('data/sprite/악세사리/여/여_' . $v . '.act','data/sprite/악세사리/여/F' . $n . '.act')) ? '[+] data/sprite/악세사리/여/여_' . $v . ' was successfully renamed to data/sprite/악세사리/여/F' . $n : '[!] Error renaming file data/sprite/악세사리/여/여_' . $v);
		say((&ren('data/sprite/악세사리/여/여_' . $v . '.spr','data/sprite/악세사리/여/F' . $n . '.spr')) ? '[+] data/sprite/악세사리/여/여_' . $v . ' was successfully renamed to data/sprite/악세사리/여/F' . $n : '[!] Error renaming file data/sprite/악세사리/여/여_' . $v);
		say((&ren('data/sprite/아이템/' . $v . '.act','data/sprite/아이템/' . $n . '.act'))               ? '[+] data/sprite/아이템/' . $v . ' was successfully renamed to data/sprite/아이템/' . $n               : '[!] Error renaming file data/sprite/아이템/' . $v);
		say((&ren('data/sprite/아이템/' . $v . '.spr','data/sprite/아이템/' . $n . '.spr'))               ? '[+] data/sprite/아이템/' . $v . ' was successfully renamed to data/sprite/아이템/' . $n               : '[!] Error renaming file data/sprite/아이템/' . $v);		
	}
}

close($arq);