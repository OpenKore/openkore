use strict;
use warnings FATAL => 'all';

package SVN::Updater;
use base 'Class::Accessor';
__PACKAGE__->mk_accessors('path', 'changes');
use Carp;

our $VERSION = 0.01;

sub _svn_command {
	my ($self, $cmd, @params) = @_;
	my $cmd_line = "cd " . $self->path . " && svn $cmd ";
	$cmd_line .= join(' ', map { quotemeta($_) } @params) if @params;
	my @res = `$cmd_line 2>&1`;
	return -1 if ($cmd eq "help" && $?);
	confess "Unable to do $cmd_line\n" . join('', @res) if $?;
	return @res;
}

sub _load_status {
	my $self = shift;
	foreach ($self->_svn_command('status')) {
		chomp;
		/^(.).{6}(.+)$/;
		push @{ $self->{$1} }, $2;
	}
}

# Constructs SVN::Updater instance. Loads current status of the directory
# given by 'path' option.
sub new {
	my $self = shift()->SUPER::new(@_);
	$self->changes([]) unless $self->changes;
	return $self;
}

sub load {
	my $self = shift()->new(@_);
	$self->_load_status;
	return $self;
}

# Give info about current Repos
sub info {
	my ($self, @params) = @_;
	my $local_ver;
	my $global_ver;
	$local_ver = $global_ver = 0;
	$self->_svn_command('cleanup'); # Cleaup Repos, if something go wrong
	foreach ($self->_svn_command('info', @params)) {
		chomp;
		my ($key, $val) = split(/:/);
		$local_ver = int ($val) if (defined $key && $key eq "Revision");
		$global_ver = int ($val) if (defined $key && $key eq "Last Changed Rev");
	}
	return ($local_ver, $global_ver);
};

# Returns array of files which are currently modified.
sub modified {
	return shift()->{M} || [];
}

# Returns array of file which are scheduled for addition.
sub added {
	return shift()->{A} || [];
}

# Returns array of files which do not exist in svn repository. 
sub unknown {
	return shift()->{'?'} || [];
}

# Returns array of files which are scheduled for deletion.
sub deleted {
	return shift()->{D} || [];
}

# Returns array of files which are missing from the working directory.
sub missing {
	return shift()->{'!'} || [];
}

# Updates current working directory from the latest repository contents.
sub update {
	my ($self, @params) = @_;
	$self->_svn_command('cleanup'); # Cleaup Repos, if something go wrong
	return $self->_svn_command('update', @params);
}

# Diffs the file against the repository.
sub diff {
	return join('', shift()->_svn_command('diff', @_));
}

# Checks-out working copy from the REPOSITORY into directory given by 'path' option.
sub checkout {
	my ($self, $repository) = @_;
	mkdir($self->path) or confess "Unable to create " . $self->path;
	return $self->_svn_command('checkout', $repository, '.');
}

1;
