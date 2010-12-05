package Interface::Wx::Base::SkillList;

use strict;
use base 'Interface::Wx::Base::List';

use Wx ':everything';

use Globals qw/%skillsDesc_lut/;
use Translation qw/T TF/;

sub new {
	my ($class, $parent, $id) = (shift, shift, shift);
	
	my $self = $class->SUPER::new($parent, $id, @_);
	
	$self->{list}->SetSingleStyle(wxLC_SINGLE_SEL);
	
	$self->{list}->InsertColumn(0, do {
		local $_ = Wx::ListItem->new;
		$_->SetAlign(wxLIST_FORMAT_RIGHT);
		$_->SetWidth(50);
	$_ });
	$self->{list}->InsertColumn(1, do {
		local $_ = Wx::ListItem->new;
		$_->SetAlign(wxLIST_FORMAT_RIGHT);
		$_->SetWidth(26);
	$_ });
	$self->{list}->InsertColumn(2, do {
		local $_ = Wx::ListItem->new;
		$_->SetWidth(18);
	$_ });
	$self->{list}->InsertColumn(3, do {
		local $_ = Wx::ListItem->new;
		$_->SetWidth(125);
	$_ });
	$self->{list}->InsertColumn(4, do {
		local $_ = Wx::ListItem->new;
		$_->SetWidth(26);
	$_ });
	
	$self->{color} = {
		enemy => new Wx::Colour('FIREBRICK'),
		location => new Wx::Colour('BLUE'),
		self => new Wx::Colour('DARK GREEN'),
		actors => new Wx::Colour('DARK GREEN'),
		unavailable => new Wx::Colour('DARK GREY'),
		other => new Wx::Colour('BLACK'),
	};
	
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	
	Plugins::delHooks ($self->{hooks});
}

sub getSelection { map {new Skill(idn => $_)} @{$_[0]{selection}} }

sub setItem {
	my ($self, $index, $skill, $up) = @_;
	
	if ($skill) {
		my ($level, $target) = ($skill->getLevel, $skill->getTargetType);
		
		$self->SUPER::setItem($index, [
			$index,
			$level,
			$up ? '+' : '',
			$skill->getName,
			$target != Skill::TARGET_PASSIVE && $level && $skill->getSP($level) || '',
		], (
			!$level ? $self->{color}{unavailable}
			: $target == Skill::TARGET_ENEMY ? $self->{color}{enemy}
			: $target == Skill::TARGET_LOCATION ? $self->{color}{location}
			: $target == Skill::TARGET_SELF ? $self->{color}{self}
			: $target == Skill::TARGET_ACTORS ? $self->{color}{actors}
			: $self->{color}{other}
		));
	} else {
		$self->SUPER::setItem($index);
	}
}

1;
