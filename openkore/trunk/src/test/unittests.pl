#!/usr/bin/env perl
use strict;
use FindBin qw($RealBin);
use lib "$RealBin/..";

use Test::More qw(no_plan);
use CallbackListTest;
use ObjectListTest;
use ActorListTest;

CallbackListTest::start();
ObjectListTest::start();
ActorListTest::start();
