package Interface::Wx::Base::Store;
use strict;

use Wx ':everything';
use base 'Wx::Panel';
use Wx::Event ':everything';

use Interface::Wx::Base::ArrayListCtrl;
use Interface::Wx::Base::SparseArrayListCtrl;
use Interface::Wx::Context::Item;

use Globals qw($char);
use Utils qw(formatNumber);
use Translation qw(T TF);

sub new {
	my ($class, $parent, $id, $args) = @_;
	
	Scalar::Util::weaken(my $weak = my $self = $class->SUPER::new($parent, $id));
	
	my $updateTotal = sub {
		return unless my ($sel) = $weak->{list}->getSelection;
		$weak->{control}{zenyBefore}->SetLabel(formatNumber($char->{zeny}));
		$weak->{control}{total}->SetLabel(formatNumber(my $total = $sel->{price} * $weak->{control}{amount}->GetValue));
		$weak->{control}{zenyAfter}->SetLabel(formatNumber($char->{zeny} - $total));
	};
	
	$self->SetSizer(my $sizer = new Wx::BoxSizer(wxVERTICAL));
	$sizer->Add($self->{list} = ({
		sparse => 'Interface::Wx::Base::SparseArrayListCtrl',
	}->{$args->{source}} // 'Interface::Wx::Base::ArrayListCtrl')->new($self, wxID_ANY, {
		cols => 3,
		heading => [T('Amount'), T('Item'), T('Price')],
		format => [wxLIST_FORMAT_RIGHT, wxLIST_FORMAT_LEFT, wxLIST_FORMAT_RIGHT],
		getText => sub { $_[0]->{amount} // '∞', $_[0]->{name}, formatNumber($_[0]->{price}) },
		update => sub {
			if (
				local ($_) = $weak->{list}->getSelection
				and my $max = List::Util::min(int($char->{zeny} / $_->{price}), $_->{amount} // 30000)
			) {
				$weak->{control}{amount}->SetRange(1, $max);
				$weak->{control}{amount}->Enable;
				$weak->{control}{buy}->Enable;
			} else {
				$weak->{control}{amount}->Disable;
				$weak->{control}{buy}->Disable;
			}
			&{$updateTotal};
		},
		context => sub {
			if (my (@sel) = $weak->{list}->getSelection) { Interface::Wx::Context::Item->new($weak, \@sel)->popup }
		},
		%$args,
	}), 1, wxEXPAND);
	
	$self->{control}{amount} = new Wx::SpinCtrl($self, wxID_ANY);
	my $size = $self->{control}{amount}->GetBestSize;
	
	my $labelMaker = sub {
		my ($title, $controlref) = @_;
		sub {
			my ($sizer) = @_;
			
			$sizer->Add(new Wx::StaticText($self, wxID_ANY, '', wxDefaultPosition, [-1, $size->GetHeight]), 0);
			$sizer->Add(new Wx::StaticText($self, wxID_ANY, $title), 0, wxALIGN_CENTER_VERTICAL);
			$sizer->Add($$controlref = new Wx::StaticText(
				$self, wxID_ANY, '', wxDefaultPosition, [$size->GetWidth, -1], wxST_NO_AUTORESIZE
			), 0, wxALIGN_CENTER_VERTICAL);
		}
	};
	$sizer->Add($_, 0, wxEXPAND) for map {
		my $sizer = new Wx::BoxSizer(wxHORIZONTAL);
		$sizer->AddStretchSpacer;
		$_->($sizer);
		$sizer
	} (
		$labelMaker->(T('Available zeny: '), \$self->{control}{zenyBefore}),
		sub {
			my ($sizer) = @_;
			
			$sizer->Add(new Wx::StaticText($self, wxID_ANY, T('Amount to buy: ')), 0, wxALIGN_CENTER_VERTICAL);
			$sizer->Add($self->{control}{amount}, 0, wxALIGN_CENTER_VERTICAL);
		},
		$labelMaker->(T('Total price: '), \$self->{control}{total}),
		$labelMaker->(T('Remaining zeny: '), \$self->{control}{zenyAfter}),
		sub {
			my ($sizer) = @_;
			
			$sizer->Add($self->{control}{buy} = new Wx::Button($self, wxID_ANY, T('Buy')), 0, wxALIGN_CENTER_VERTICAL);
		}
	);
	
	EVT_SPINCTRL($self, $self->{control}{amount}->GetId, $updateTotal);
	EVT_BUTTON($self, $self->{control}{buy}->GetId, sub { $weak->_onBuy; Plugins::callHook('interface/defaultFocus') });
	
	$self->{list}->update;
	
	$self
}

sub getAmount { $_[0]->{control}{amount}->IsEnabled && $_[0]->{control}{amount}->GetValue }

1;
