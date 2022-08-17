#!/usr/bin/env perl
use strict;
use FindBin qw($RealBin);
use lib "$RealBin";
use lib "$RealBin/..";
use lib "$RealBin/../deps";
use lib "$RealBin/../auto/XSTools";
use lib "$RealBin/../..";
use List::MoreUtils;
use Test::More qw(no_plan);

print "Run tests on $^O\n";

my @tests = qw(
    Utils::TextReaderTest
	CallbackListTest ObjectListTest ActorListTest WhirlpoolTest RijndaelTest
	SetTest SkillTest InventoryListTest
	ItemsTest
	ShopTest
	TaskManagerTest TaskWithSubtaskTest TaskChainedTest
	TaskTalkNPCTest
	PluginsHookTest
	FileParsersTest
	NetworkTest
	FieldTest
);
if ($^O eq 'MSWin32') {
	push @tests, qw(HttpReaderTest);
}

@tests = @ARGV if (@ARGV);
foreach my $module (@tests) {
	$module =~ s/\.pm$//;
	my $file = $module;
	$file =~ s{::}{/}g;
	eval {
		require "$file.pm";
	};
	if ($@) {
		$@ =~ s/\(\@INC contains: .*?\) //s;
		print STDERR "Cannot load unit test $module:\n$@\n";
		exit 1;
	}
	print "#### Starting $module test ####\n";
	$module->start;
}
