package Interface::Wx::Window::Skills;

use strict;
use base 'Interface::Wx::Base::SkillList';

use Globals qw/$char/;
use Translation qw/T TF/;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id, [
		{key => 'points', title => 'Skill points:'},
	]);
	
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
	return unless my $skill = $self->getSelection;
	
	Scalar::Util::weaken(my $weak = $self);
	
	my @menu = {title => $skill->getName . '...'}, {};
	
	my $target = $skill->getTargetType;
	
	if ($target == Skill::TARGET_SELF || $target == Skill::TARGET_ACTORS) {
		push @menu, {title => T('Use on self'), callback => sub { $weak->_onActivate }};
	}
	# TODO: submenus with current environment?
	if ($target == Skill::TARGET_ACTORS) {
		push @menu, {title => T('Use on player')};
	}
	if ($target == Skill::TARGET_ENEMY) {
		push @menu, {title => T('Use on monster')};
	}
	
	if ($char->{skills}{$skill->getHandle} && $char->{skills}{$skill->getHandle}{up}) {
		push @menu, {}, {title => T('Level up'), callback => sub { $weak->_onLevelUp }};
	}
	
	$self->contextMenu(\@menu);
}

sub _onActivate {
	my ($self) = @_;
	return unless my $skill = $self->getSelection;
	
	my $target = $skill->getTargetType;
	
	if ($target == Skill::TARGET_SELF || $target == Skill::TARGET_ACTORS) {
		Commands::run("ss " . $skill->getIDN);
	}
}

sub _onLevelUp {
	my ($self) = @_;
	return unless my $skill = $self->getSelection;
	
	Commands::run("skills add " . $skill->getIDN);
}

1;
