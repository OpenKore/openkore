package Interface::Wx::Window::Deal;
use strict;

use Wx ':everything';
use base 'Wx::Panel';
use Wx::Event ':everything';

use Interface::Wx::Base::HashListCtrl;
use Interface::Wx::Context::Item;

use Globals qw($char %incomingDeal %currentDeal);
use Misc qw(itemNameSimple);
use Translation qw(T TF);

{
	my $hooks;
	
	sub new {
		my ($class, $parent, $id, $args) = @_;
		
		Scalar::Util::weaken(my $weak = my $self = $class->SUPER::new($parent, $id));
		$self->{title} = T('Deal');
		
		$self->SetSizer(my $sizer = new Wx::BoxSizer(wxVERTICAL));
		
		$self->{you}{zeny} = new Wx::SpinCtrl($self, wxID_ANY);
		my $size = $self->{you}{zeny}->GetBestSize;
		
		$sizer->Add(do { my $sizer = new Wx::BoxSizer(wxHORIZONTAL);
			$sizer->Add($self->{you}{name} = new Wx::StaticText($self, wxID_ANY, T('You')), 0, wxEXPAND);
			$sizer->AddStretchSpacer;
			$sizer->Add($self->{other}{name} = new Wx::StaticText($self, wxID_ANY, ''), 0, wxEXPAND);
		$sizer }, 0, wxEXPAND);
		
		$sizer->Add(do { my $sizer = new Wx::BoxSizer(wxHORIZONTAL);
			foreach my $i (qw(you other)) {
				$sizer->Add(do { my $sizer = new Wx::BoxSizer(wxVERTICAL);
					$sizer->Add($self->{$i}{list} = new Interface::Wx::Base::HashListCtrl($self, wxID_ANY, {
						cols => 2,
						heading => [T('Amount'), T('Item')],
						format => [wxLIST_FORMAT_RIGHT, wxLIST_FORMAT_LEFT],
						getText => sub { $_[0]->{amount}, $_[0]->{name} || itemNameSimple($_[0]->{nameID}) },
						context => sub {
							if (my (@sel) = $weak->{$i}{list}->getSelection) { Interface::Wx::Context::Item->new($weak, \@sel)->popup }
						},
						hashref => $currentDeal{$i},
					}), 1, wxEXPAND);
				$sizer }, 1, wxEXPAND)
			};
		$sizer }, 1, wxEXPAND);
		
		$sizer->Add(do { my $sizer = new Wx::BoxSizer(wxHORIZONTAL);
			$sizer->Add(new Wx::StaticText($self, wxID_ANY, T('Zeny: ')), 0, wxALIGN_CENTER_VERTICAL);
			$sizer->Add($self->{you}{zeny}, 0, wxALIGN_CENTER_VERTICAL);
			$sizer->AddStretchSpacer;
			$sizer->Add(new Wx::StaticText($self, wxID_ANY, T('Zeny: ')), 0, wxALIGN_CENTER_VERTICAL);
			$sizer->Add($self->{other}{zeny} = new Wx::StaticText($self, wxID_ANY, ''), 0, wxALIGN_CENTER_VERTICAL);
		$sizer }, 0, wxEXPAND);
		
		$sizer->Add(do { my $sizer = new Wx::BoxSizer(wxHORIZONTAL);
			$sizer->Add($self->{deal} = new Wx::Button($self, wxID_ANY, ''));
			$sizer->AddStretchSpacer;
			$sizer->Add($self->{cancel} = new Wx::Button($self, wxID_ANY, T('Cancel')));
		$sizer }, 0, wxEXPAND);
		
		EVT_SPINCTRL($self, $self->{you}{zeny}->GetId, sub { $currentDeal{you_zeny} = $weak->{you}{zeny}->GetValue });
		for my $i ([deal => 'deal'], [cancel => 'deal no']) {
			EVT_BUTTON($self, $self->{$i->[0]}->GetId, sub {
				Commands::run($i->[1]); $weak->_update; Plugins::callHook('interface/defaultFocus')
			})
		}
		
		$hooks = Plugins::addHooks(map {[ $_, sub { $weak->_update } ]} qw(
			packet_mapChange
			packet/deal_add_other
			packet/deal_add_you
			packet/deal_begin
			packet/deal_cancelled
			packet/deal_complete
			packet/deal_finalize
			packet/deal_request
		));
		
		$self->_update;
		
		$self
	}
	
	sub DESTROY { Plugins::delHooks($hooks) }
}

sub _update {
	my ($self) = @_;
	
	$self->{other}{name}->SetLabel($incomingDeal{name} // $currentDeal{name} // T('Other'));
	$self->{other}{zeny}->SetLabel($currentDeal{other_zeny} // '0');
	$self->{you}{zeny}->SetRange(0, $char->{zeny}) if $char;
	$self->{you}{zeny}->SetValue($currentDeal{you_zeny} // 0);
	$self->{you}{zeny}->Enable(!!%currentDeal && !$currentDeal{you_finalize});
	
	$self->{deal}->SetLabel(%incomingDeal ? T('Accept') : $currentDeal{you_finalize} ? T('Trade') : T('Deal'));
	$self->{deal}->Enable(
		%incomingDeal or %currentDeal && (
			!$currentDeal{you_finalize} or $currentDeal{other_finalize} && !$currentDeal{final}
		)
	);
	$self->{cancel}->Enable(!!%incomingDeal || !!%currentDeal);
	
	for (qw(you other)) {
		$self->{$_}{list}{args}{hashref} = $currentDeal{$_};
		$self->{$_}{list}->update;
	}
}

1;
