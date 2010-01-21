package Interface::Wx::StatView::Exp;

use strict;
use base 'Interface::Wx::StatView';

use Globals qw/$char $conState $startTime_EXP $startingzeny $totalBaseExp $totalJobExp $bytesSent $bytesReceived/;
use Translation qw/T TF/;
use Utils qw/formatNumber timeConvert timeOut/;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id,
		[
			{key => 'time', title => T('Botting time'), type => 'stat'},
			{key => 'baseExp', title => T('BaseExp'), type => 'stat'},
			{key => 'baseExpPerHour', title => T('BaseExp/Hour'), type => 'stat'},
			{key => 'jobExp', title => T('JobExp'), type => 'stat'},
			{key => 'jobExpPerHour', title => T('JobExp/Hour'), type => 'stat'},
			{key => 'zeny', title => T('Zeny'), type => 'stat'},
			{key => 'zenyPerHour', title => T('Zeny/Hour'), type => 'stat'},
			{key => 'baseEstimation', title => T('Base Levelup Time Estimation'), type => 'stat'},
			{key => 'jobEstimation', title => T('Job Levelup Time Estimation'), type => 'stat'},
			{key => 'deaths', title => T('Died'), type => 'stat'},
			{key => 'bytesSent', title => T('Bytes Sent'), type => 'stat'},
			{key => 'bytesReceived', title => T('Bytes Received'), type => 'stat'},
			
			{key => 'reset', title => T('Reset'), type => 'control'},
		],
	);
	
	$self->{hooks} = Plugins::addHooks (
		['mainLoop_post', sub { $self->update }],
	);
	
	$self->set ('reset', 1);
	
	$self->update;
	
	return $self;
}

sub unload {
	my ($self) = @_;
	
	Plugins::delHooks ($self->{hooks});
}

sub update {
	my ($self) = @_;
	
	return unless $char;
	
	return unless timeOut ($self->{updateTime}, 1);
	$self->{updateTime} = time;
	
	$self->Freeze;
	
	my $bottingSecs = int time - $startTime_EXP;
	my $bottingHours = $bottingSecs / 3600;
	my $value;
	
	$self->set ('time', timeConvert ($bottingSecs));
	$self->set ('deaths', $char->{deathCount} || 0);
	if ($bottingSecs > 0) {
		$self->set ('baseExp', formatNumber ($totalBaseExp) . (
			$char->{exp_max} ? sprintf(" (%.2f\%)", $totalBaseExp * 100 / $char->{exp_max}) : ''
		));
		$value = int $totalBaseExp / $bottingHours;
		$self->set ('baseExpPerHour', formatNumber ($value) . (
			$char->{exp_max} ? sprintf(" (%.2f\%)", $value * 100 / $char->{exp_max}) : ''
		));
		$self->set ('baseEstimation', $char->{exp_max} && $value ? timeConvert (
			int + ($char->{exp_max} - $char->{exp}) / ($value / 3600)
		) : '');
		$self->set ('jobExp', formatNumber ($totalJobExp) . (
			$char->{exp_job_max} ? sprintf(" (%.2f\%)", $totalJobExp * 100 / $char->{exp_job_max}) : ''
		));
		$value = int $totalJobExp / $bottingHours;
		$self->set ('jobExpPerHour', formatNumber ($value) . (
			$char->{exp_job_max} ? sprintf(" (%.2f\%)", $value * 100 / $char->{exp_job_max}) : ''
		));
		$self->set ('jobEstimation', $char->{exp_job_max} && $value ? timeConvert (
			int + ($char->{exp_job_max} - $char->{exp_job}) / ($value / 3600)
		) : '');
		$self->set ('zeny', formatNumber ($value = $char->{zeny} - $startingzeny));
		$self->set ('zenyPerHour', formatNumber (int $value / $bottingHours));
		$self->set ('bytesSent', formatNumber ($bytesSent));
		$self->set ('bytesReceived', formatNumber ($bytesReceived));
	}
	
	$self->GetSizer->Layout;
	
	$self->Thaw;
}

sub _onControl {
	my ($self, $key) = @_;
	
	if ($key eq 'reset') {
		Commands::run ('exp reset');
	}
}

1;
