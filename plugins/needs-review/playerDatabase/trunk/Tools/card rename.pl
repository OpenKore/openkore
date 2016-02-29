#!/usr/bin/perl
use strict;
use warnings;
use feature qw(say);

sub ren() {
    return((rename($_[0],$_[1])) ? 1 : 0);
}

open(my $arq,'+<num2cardillustnametable.txt') || die "$!\n";
while(<$arq>) {
    chomp;
    my($n,$v) = /^([\w]+)\#(.+)#$/;
    say((&ren("$v.bmp","$n.jpg")) ? "[+] $v was successfully renamed to $n" : "[!] Error renaming file $v");
}

close($arq);