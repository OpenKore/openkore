package Interface::Wx::Base::SkillList;

use strict;
use base 'Interface::Wx::Base::List';

use Wx ':everything';

use Globals qw/%skillsDesc_lut/;
#use Misc qw/items_control pickupitems/;
use Translation qw/T TF/;
#use Utils qw/formatNumber/;

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
		$_->SetWidth(125);
	$_ });
	$self->{list}->InsertColumn(3, do {
		local $_ = Wx::ListItem->new;
		$_->SetWidth(26);
	$_ });
	
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	
	Plugins::delHooks ($self->{hooks});
}

sub getSelection { new Skill(idn => ${$_[0]{selection}}[0]) }

sub setItem {
	my ($self, $index, $item) = @_;
	
	if ($item) {
		my ($level, $target) = ($item->getLevel, $item->getTargetType);
		
		$self->SUPER::setItem($index, [
			$index,
			$level,
			$item->getName,
			$target != Skill::TARGET_PASSIVE && $level && $item->getSP($level) || '',
		]);
	} else {
		$self->SUPER::setItem($index);
	}
}

sub removeAllItems {
	my ($self) = @_;
	
	$self->{list}->DeleteAllItems;
}

sub contextMenu {
	my ($self, $items) = (shift, shift);
	
	if (my $skill = $self->getSelection) {
		if (my $control = $skillsDesc_lut{$skill->getHandle}) {
			chomp $control;
			push @$items, {}, {title => T('Description'), menu => [{title => $control}]};
		}
	}
	
	return $self->SUPER::contextMenu($items, @_);
}

1;
