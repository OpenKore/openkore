package Interface::Wx::Base::Context;

use strict;
use Wx ':everything';
use Wx::Event ':everything';

use Globals qw($char);
use Misc qw(launchURL);
use Translation qw(T TF);

sub new {
	my $self = bless {}, shift;
	
	$self->{parent} = shift;
	$self->{head} = shift || [];
	$self->{tail} = shift || [];
	
	return $self;
}

sub add {
	my $self = shift;
	
	while (my $item = shift) {
		if (%$item) {
			$self->{menu}->Append(
				my $menuItem = new Wx::MenuItem(
					undef, wxID_ANY, $item->{title}, undef,
					exists $item->{check} ? wxITEM_CHECK : exists $item->{radio} ? wxITEM_RADIO : wxITEM_NORMAL,
					$item->{menu} ? __PACKAGE__->new(undef, $item->{menu})->menu : undef,
				)
			);
			$menuItem->Check(1) if $item->{check} || $item->{radio};
			if ($item->{callback}) {
				EVT_MENU($self->{menu}, $menuItem->GetId, $item->{callback});
			} elsif ($item->{command}) {
				EVT_MENU($self->{menu}, $menuItem->GetId, sub { Commands::run($item->{command}) });
			} elsif ($item->{url}) {
				EVT_MENU($self->{menu}, $menuItem->GetId, sub { launchURL($item->{url}) });
			} elsif (!$item->{menu} || !$menuItem->GetSubMenu->GetMenuItemCount) {
				$menuItem->Enable(0);
			}
		} elsif ($self->{menu}->GetMenuItemCount && scalar @_) {
			$self->{menu}->AppendSeparator;
		}
	}
}

sub menu {
	my ($self) = @_;
	
	$self->{menu} = new Wx::Menu;
	$self->add(@{$self->{head}}, reverse @{$self->{tail}});
	return $self->{menu};
}

sub popup {
	my ($self) = @_;
	
	$self->{parent}->PopupMenu($self->menu, wxDefaultPosition);
}

sub useSkillMenu {
	my ($self, $filter, $item) = @_;
	
	map {{ title => TF("%s [%d]", $_->getName, $_->getLevel), $item->($_) }}
	sort { $a->getName cmp $b->getName }
	grep { $filter->($_) }
	map { Skill->new(handle => $_, level => $char->{skills}{$_}{lv}) }
	keys %{$char->{skills}}
}

1;
