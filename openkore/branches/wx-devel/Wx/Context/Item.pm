package Interface::Wx::Context::Item;

use strict;
use base 'Interface::Wx::Base::Context';

use Wx ':everything';

use Globals qw/$char %config %itemsDesc_lut %shop %arrowcraft_items %items_control %pickupitems/;
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
		? TF('%d Items (%d Total)', scalar @$objects, List::Util::sum map { $_->{amount} } @$objects)
		: join '; ', map { join ' ', @$_{'amount', 'name'} } @$objects
	};
	
	if (@$objects == 1) {
		my ($object) = @$objects;
		my $name = $object->{name};
		
		push @tail, {};
		
		# TODO: more grained item type check for each option
		if (isEquip($object)) {
			my @submenu;
			for (
				['autoSwitch_default_rightHand', T('Default for Right Hand')],
				['autoSwitch_default_leftHand', T('Default for Left Hand')],
				['autoSwitch_default_arrow', T('Default for Arrows')],
			) {
				my ($option, $title) = @$_;
				my $check = lc $name eq lc $config{$option};
				push @submenu, {
					title => $title, check => $check,
					callback => sub { Misc::bulkConfigModify({$option => $check ? undef : $name}, 1) }
				}
			}
			push @tail, {title => T('Auto-Equip'), menu => \@submenu};
		}
		
		{
			my $control = items_control($name);
			my @submenu;
			push @submenu, {title => TF('Keep %s Minimum', formatNumber($control->{keep}))};
			for (
				['storage', T('Auto-Store')],
				['sell', T('Auto-Sell')],
				['cart_add', T('Auto-Put in Cart')],
				['cart_get', T('Auto-Get from Cart')],
			) {
				my $value = join ' ', $name,
				map {$_ || 0} @{{%$control, @$_[0] => $control->{@$_[0]} ? 0 : 1}} {qw/keep storage sell cart_add cart_get/};
				$value =~ s/\s+\S+\K\s+[ 0]*$//;
				push @submenu, {
					title => @$_[1], check => $control->{@$_[0]},
					$Commands::customCommands{iconf} && (command => "iconf $value")
				}
			}
			push @tail, {title => TF('Item Control%s', $items_control{lc $name} ? T(' (Configured)') : T(' (Default)')), menu => \@submenu};
		}
		
		{
			my $control = pickupitems($name);
			my @submenu;
			for (
				[-1, T('Auto-Drop')],
				[0, T('Ignore')],
				[1, T('Auto-Pick Up')],
				[2, T('Auto-Pick Up Quickly')],
			) {
				push @submenu, {
					title => @$_[1], radio => $control == @$_[0],
					$Commands::customCommands{pconf} && (command => "pconf " . (join ' ', $name, @$_[0]))
				}
			}
			push @tail, {title => TF('Pickup%s', $pickupitems{lc $name} ? T(' (Configured)') : T(' (Default)')), menu => \@submenu};
		}
		
		if (
			$char->{skills}{MC_VENDING} && $char->{skills}{MC_VENDING}{lv}
			&& $shop{items} and my ($control) = grep {$_->{name} eq $name} @{$shop{items}}
		) {
			# TODO
			push @tail, {title => $control->{amount}
				? TF('Vend %s for %s Each', formatNumber($control->{amount}), formatNumber($control->{price}))
				: TF('Vend for %s Each', formatNumber($control->{price}))
			};
		}
		if ($char->{skills}{AC_MAKINGARROW} && $char->{skills}{AC_MAKINGARROW}{lv}) {
			# TODO
			push @tail, {title => TF('Auto Arrow Crafting'), check => $arrowcraft_items{lc $name}};
		}
		
		push @tail, {};
		push @tail, {title => T('Lookup in...'), menu => [map {{ title => $_->[0], url => do { $_->[1] =~ s/%ID%/$object->{nameID}/; $_->[1] } }} (
			['Amesani' => 'http://ro.amesani.org/db/item-info/%ID%/'],
			['RateMyServer' => 'http://ratemyserver.net/index.php?page=item_db&item_id=%ID%'],
		)]};
		if (my $control = $itemsDesc_lut{$object->{nameID}}) {
			chomp $control;
			push @tail, {title => T('Description'), menu => [{title => $control}]};
		}	
	}
	
	push @{$self->{tail}}, reverse @tail;
	return $self;
}

1;
