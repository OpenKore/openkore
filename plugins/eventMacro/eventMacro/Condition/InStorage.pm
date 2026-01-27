package eventMacro::Condition::InStorage;

use strict;

use base 'eventMacro::Condition::Base::InStorage';

use Globals qw( $char );

sub _parse_syntax {
my ( $self, $condition_code ) = @_;

$self->{member_list} = [];
my $error_message = "Item name must be inside quotation marks and a numeric comparison must be given";

foreach my $member (split(/\s*,\s*/, $condition_code)) {
next if ($member eq '');
if ($member =~ /"(.+)"\s+(\S.*)/) {
my ($wanted, $comparison) = ($1, $2);
my $validator = eventMacro::Validator::NumericComparison->new($comparison);

if (defined $validator->error) {
$self->{error} = $validator->error;
return 0;
}

push ( @{ $self->{variables} }, @{$validator->variables} );
push ( @{ $self->{member_list} }, { wanted => $wanted, validator => $validator } );
} else {
$self->{error} = $error_message;
return 0;
}
}

unless (@{ $self->{member_list} }) {
$self->{error} = $error_message;
return 0;
}

$self->{wanted} = $self->{member_list}[0]{wanted};
$self->SUPER::_parse_syntax($condition_code);
}

sub _get_val {
my ( $self, $wanted ) = @_;
$wanted ||= $self->{wanted};
$char->storage->sumByName($wanted);
}

1;
