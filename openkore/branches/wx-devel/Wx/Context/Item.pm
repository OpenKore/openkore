package Interface::Wx::Context::Item;

use strict;
use base 'Interface::Wx::Base::Context';

use Wx ':everything';

use Globals qw/%itemsDesc_lut %shop/;
use Misc qw/items_control pickupitems/;
use Translation qw/T TF/;
use Utils qw/formatNumber/;
use Interface::Wx::Utils qw(isUsable isEquip isCard);

sub new {
	my ($class, $parent, $objects) = @_;
	
	my $self = $class->SUPER::new ($parent);
	
	my @tail;
	
	push @{$self->{head}}, {}, {
		title => @$objects > 3
		? TF('%d items (%d total)', scalar @$objects, List::Util::sum map { $_->{amount} } @$objects)
		: join '; ', map { join ' ', @$_{'amount', 'name'} } @$objects
	};
	
	if (@$objects == 1) {
		my ($object) = @$objects;
		
		my $control = items_control($object->{name});
		push @tail, {}, {title => TF('Keep %s minimum', formatNumber($control->{keep}))};
		for (
			['storage', T('Auto-store')],
			['sell', T('Auto-sell')],
			['cart_add', T('Auto-put in cart')],
			['cart_get', T('Auto-get from cart')],
		) {
			my $value = join ' ', $object->{name},
			map {$_ || 0} @{{%$control, @$_[0] => $control->{@$_[0]} ? 0 : 1}} {qw/keep storage sell cart_add cart_get/};
			$value =~ s/\s+\S+\K\s+[ 0]*$//;
			push @tail, {
				title => @$_[1], check => $control->{@$_[0]},
				$Commands::customCommands{iconf} && (command => "iconf $value")
			}
		}
		
		$control = pickupitems($object->{name});
		push @tail, {};
		for (
			[-1, T('Auto-drop')],
			[0, T('Ignore')],
			[1, T('Auto-pick up')],
			[2, T('Auto-pick up quickly')],
		) {
			push @tail, {
				title => @$_[1], radio => $control == @$_[0],
				$Commands::customCommands{pconf} && (command => "pconf " . (join ' ', $object->{name}, @$_[0]))
			}
		}
		
		if ($shop{items} and ($control) = grep {$_->{name} eq $object->{name}} @{$shop{items}}) {
			push @tail, {}, {title => $control->{amount}
				? TF('Vend %s for %s each', formatNumber($control->{amount}), formatNumber($control->{price}))
				: TF('Vend for %s each', formatNumber($control->{price}))
			};
		}
		
		if ($control = $itemsDesc_lut{$object->{nameID}}) {
			chomp $control;
			push @tail, {}, {title => T('Description'), menu => [{title => $control}]};
		}	
	}
	
	push @{$self->{tail}}, reverse @tail;
	return $self;
}

1;
