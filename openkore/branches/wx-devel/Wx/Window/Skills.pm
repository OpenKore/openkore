package Interface::Wx::Window::Skills;

use strict;
use base 'Interface::Wx::Base::SkillList';

use Globals qw/$char/;
use Translation qw/T TF/;

use Interface::Wx::Context::Skill;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id, [
		{key => 'points', title => 'Skill points:'},
	]);
	
	$self->{title} = T('Skills');
	
	Scalar::Util::weaken(my $weak = $self);
	
	$self->{hooks} = Plugins::addHooks(
		['packet/map_loaded', sub {
			$weak->clear
		}],
		['packet_charSkills', sub {
			$weak->onSkillChange($_[1])
		}],
		['packet/stat_info', sub {
			$weak->onStatInfo
		}],
	);
	
	$self->update;
	
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	
	Plugins::delHooks ($self->{hooks});
}

sub onSkillChange {
	my ($self, $args) = @_;
	
	$self->setItem($args->{ID}, new Skill(handle => $args->{handle}, level => $args->{level}));
}

sub onStatInfo {
	my ($self) = @_;
	return unless $char;
	
	$self->setStat('points', $char->{points_skill});
}

sub update {
	my ($self) = @_;
	return unless $char;
	
	$self->Freeze;
	$self->setItem($char->{skills}{$_}{ID},
		new Skill(handle => $_, level => $char->{skills}{$_}{lv})
	) for sort {$char->{skills}{$a}{ID} <=> $char->{skills}{$b}{ID}} keys %{$char->{skills}};
	
	$self->onStatInfo;
	
	$self->Thaw;
}

sub clear {
	$_[0]->removeAllItems;
}

sub _onRightClick {
	my ($self) = @_;
	
	return unless scalar(my @selection = $self->getSelection);
	Interface::Wx::Context::Skill->new($self, \@selection)->popup;
}

1;
