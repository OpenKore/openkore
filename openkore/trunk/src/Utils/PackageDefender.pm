#########################################################################
#  OpenKore - Package Defender
#
#  Copyright (c) 2010 OpenKore Development Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: More ObjectOriented access and prevent AutoVivify
#
# This package used to make Package/Class more OO and brings more
# usual access control.
# Also, this package prevents AutoVivification on main package Hash.
#
##
# TODO
# 1) Improve RegExp Filters
# 2) Make Tie work only for Hash
# 3) Do not Tie where overloading used ( optional ??? )
# 4) Improve Dump function
# 5) Make FIRSTKEY, NEXTKEY, CLEAR, UNTIE work using our Rules
# 6) Improve and optimize Access Filter ( together with TODO[1] )
# 7) Add private and protected functions protection using GLOB Redefine ( on load time ??? )
# 8) Call Error is AutoVivification happens
##


package Utils::PackageDefender;

use strict;
use warnings;

use Data::Dumper ();

## ----------------------------------------------------------------------------
## package variables
## ----------------------------------------------------------------------------

# TODO
# Improve RegExp Filters

my $KEY_CREATION_ACCESS_REGEX  = qr/^new$/;

my $PROTECTED_FIELD_IDENTIFIER = qr/^[a-zA-Z][a-zA-Z0-9_]+/;
my $PRIVATE_FIELD_IDENTIFIER   = qr/^_/;

my $NO_SCRICT_BLESS = qr(^@{[join '|', __PACKAGE__, qw/utf8/]}$);
my $GLOBAL_ALLOWED_PACKAGE = qr(^@{[join '|', qw/Exporter/]}$); # Utils Settings

sub handleError {
	my ($error, $other_params) = @_;
	
	# this can be called too early, ErrorHandler will provide normal error report if loaded
	die $error;
}    

## ----------------------------------------------------------------------------
## import interface
## ----------------------------------------------------------------------------

sub import {
    shift;
    # overload bless 
    *CORE::GLOBAL::bless = \&Utils::PackageDefender::strict_bless;
}

## ----------------------------------------------------------------------------
## bless function
## ----------------------------------------------------------------------------

# TODO
# Make Tie work only for Hash
# Do not Tie where overloading used ( optional ??? )
sub strict_bless {
	my ($hash, $class) = @_;
	
	$class ||= [caller(1)]->[0]; # one-arg bless
	
	# use it only for ObjectLists for now
	if (ref $hash eq 'HASH' && $class->isa('ObjectList')) {
	#if (ref $hash eq 'HASH' && $class !~ $NO_SCRICT_BLESS) {
		tie(%{$_[0]}, "Utils::PackageDefender", $class, %{$hash});
	}
	return CORE::bless($_[0], $class);
}

## ----------------------------------------------------------------------------
## class methods
## ----------------------------------------------------------------------------

# TODO
# Improve Dump function
sub Dump {
    my ($object) = @_;
    my $tied_hash = tied(%{$object}) || die "not a Utils::PackageDefender object";
    if ($tied_hash->isa("Utils::PackageDefender")) {
        return "dumping: $tied_hash\n" . Data::Dumper::Dumper($tied_hash);
    }
}


## ----------------------------------------------------------------------------
## tie functions
## ----------------------------------------------------------------------------

sub TIEHASH { 
	my ($class, $blessed_class, %_hash) = @_;
	my ($actual_calling_class) = caller(1);	
	my $hash = { 
		blessed_class => $blessed_class,
		fields => \%_hash,
		fields_init_in => { map { $_ => $actual_calling_class } keys %_hash }
		};
	bless($hash, $class); 
	return $hash;
}

## HASH tie routines

sub STORE { 
	my ($self, $key, $value) = @_;
	$self->_check_access($key);
    $self->{fields}->{$key} = $value;
}

sub FETCH { 
	my ($self, $key) = @_;
	$self->_check_access($key);
	return $self->{fields}->{$key};
}

sub EXISTS { 
	my ($self, $key) = @_; 
	$self->_check_access($key);		
	return exists $self->{fields}->{$key}; 
}

sub DELETE {
	my ($self, $key) = @_;
	$self->_check_access($key);	
	delete $self->{fields}->{$key};
	delete $self->{fields_init_in}{$key};
}

# TODO
# Make this thing really working
sub FIRSTKEY { 
    my ($calling_package) = caller(0);
    handleError "Illegal Operation : calling FIRSTKEY not supported from $calling_package";
}

# TODO
# Make this thing really working
sub NEXTKEY { 
    my ($calling_package) = caller(0);
    handleError "Illegal Operation : calling NEXTKEY not supported from $calling_package";
}

# TODO
# Make this thing really working
sub CLEAR { 
    my ($calling_package) = caller(0);
	handleError "Illegal Operation : Clearing of this hash is strictly forbidden";
}

# TODO
# Make this thing really working
sub UNTIE {
    my ($calling_package) = caller(0);
	handleError "Illegal Operation : Un-tie-ing of this hash is strictly forbidden";
}

## ----------------------------------------------------------------------------
## private functions
## ----------------------------------------------------------------------------

# TODO
# Improve and optimize Access Filter ( together with TODO[1] )
sub _check_access {
	my ($self, $key) = @_;
	my ($calling_package, undef, undef, $hash_action) = caller(1); 
    ($calling_package ne "main") || handleError "Illegal Operation : hashes cannot be accessed directly";
	
	$hash_action =~ s/^.*:://;
	
	my (undef, undef, undef, $_calling_subroutine) = caller(2);	
    my ($calling_subroutine) = ($_calling_subroutine =~ /\:\:([a-zA-Z0-9_]+)$/);
    return if $calling_subroutine =~ /DESTROY/;
	unless (exists $self->{fields}->{$key} || $hash_action eq 'DELETE') {
		$calling_package =~ $GLOBAL_ALLOWED_PACKAGE
		or $self->{blessed_class}->isa($calling_package)
		or $calling_subroutine =~ /$KEY_CREATION_ACCESS_REGEX/
		or handleError "Illegal Operation : attempt to create non-existant key ($key) in $calling_package ($calling_subroutine)";
		
		$self->{fields_init_in}->{$key} = $calling_package;
	} else {
		unless ($calling_package =~ $GLOBAL_ALLOWED_PACKAGE) {
			if ($key =~ /$PRIVATE_FIELD_IDENTIFIER/) {	
				if ($calling_subroutine =~ /$KEY_CREATION_ACCESS_REGEX/
					&& $hash_action eq 'STORE'
					&& $calling_package ne $self->{fields_init_in}->{$key}) {
						if ($self->{fields_init_in}->{$key}->isa($calling_package)) {
							handleError "Illegal Operation : It seems that " . $self->{fields_init_in}->{$key} . " maybe stepping on one of ${calling_package}'s private fields ($key)";
						} elsif ($calling_package->isa($self->{fields_init_in}->{$key})) {
							handleError "Illegal Operation : $calling_package is stepping on a private field ($key) that belongs to " . $self->{fields_init_in}->{$key};
						} else {
							handleError "Illegal Operation : attempting to set a private field ($key) in $calling_subroutine, field was already set by " . $self->{fields_init_in}->{$key};
						}
				}
				unless ($calling_package eq $self->{fields_init_in}->{$key}) { 
					($calling_subroutine =~ /^$self->{fields_init_in}->{$key}\:\:/) || handleError "Illegal Operation : $calling_package ($calling_subroutine) attempted to access private field ($key) for " . $self->{fields_init_in}->{$key}; 
				}
			} elsif ($key =~ /$PROTECTED_FIELD_IDENTIFIER/) {	        
				($self->{blessed_class}->isa($calling_package)) || handleError "Illegal Operation : $calling_package attempted to access protected field ($key) for " . $self->{blessed_class};
			}
		}
	}
}

1;
