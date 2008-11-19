#########################################################################
#  OpenKore - Thread safe Code Referance calling functions
#
#  Copyright (c) 2006 OpenKore Development Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
package Utils::CodeRef;

use B ();
# use B::Deparse;
use FindBin qw($RealBin);
use strict;
use Scalar::Util;
use Utils;

### CATEGORY: Class CodeRef

##
# CodeRef CodeRef->new($codeRef)
#
# Create a new CodeRef object.
sub new {
	my ($class, $codeRef) = @_;
	my $self;
	$self->{cv}	= _cv($codeRef);
	$self->{packagename}	= _package_name($codeRef);
	$self->{subname}	= _sub_name($codeRef);
	my $filename = _file_name($codeRef);
	$self->{filename}	= $filename;
	$filename =~ s/\Q$RealBin\E[\/\\]//;
	$filename =~ s/[\/\\]/::/g;
	$filename =~ s/\.(pl|lp|pm)$//;
	$self->{realpackagename} = $filename;  
	# $self->{body}	= _body($codeRef);
	bless $self, $class;

	return $self;
}

##
# void $CodeRef->call([argument])
#
# Call 'CODE' referance function in this CodeRef.
sub call {
	my $self = shift;
	if (($self->{packagename})&&($self->{subname})) {
		# eval $self->{body};
		# eval ("use ". $self->{filename} . ";\n return " . $self->{packagename} . "::" . $self->{subname} . "(\@\_);\n");
		# eval ("use " . $self->{packagename} . ";\n return " . $self->{packagename} . "::" . $self->{subname} . "(\@\_);\n");
		eval ("use " . $self->{realpackagename} . ";\n return " . $self->{packagename} . "::" . $self->{subname} . "(\@\_);\n");
		if ($@) {
			die $@;
		}
	} else {
		return undef;
	};
}

##
# void $CodeRef->call2([argument])
#
# Call 'CODE' referance function in this CodeRef.
# Please note, that this function will conver the CV object back to CodeRef, and call it.
#
sub call2 {
	my $self = shift;
	eval ("use " . $self->{packagename});
	if ($@) {
		return $self->call(@_);
	};
	my $cv = $self->{cv}->object_2svref();
	return $cv->(@_);
}

#################################
#################################
# PRIVATE FUNCTIONS
#################################
#################################

sub _cv {
    my ($coderef) = @_;
    ref $coderef or return undef;
    my $cv = B::svref_2object($coderef);
    $cv->isa('B::CV') ? $cv : undef;
}

sub _sub_name {
    my $cv = &_cv or return undef;
    $cv->GV->NAME;
}

sub _package_name {
    my $cv = &_cv or return undef;
    $cv->GV->STASH->NAME;
}

sub _file_name {
    my $cv = &_cv or return undef;
    $cv->FILE;
}

# sub _body {
#    my ($coderef) = @_;
#    ref $coderef or return undef;
#	B::Deparse->new("-sC")->coderef2text($coderef);
#}

1;
