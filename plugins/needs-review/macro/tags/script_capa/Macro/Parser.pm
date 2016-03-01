# $Header$
package Macro::Parser;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(parseMacroFile parseCmd);

use Globals;
use Log qw(message error);
use Macro::Data;
use Macro::Utilities qw(setVar getVar getnpcID getItemID getStorageID
    getPlayerID getRandom getInventoryAmount getCartAmount getShopAmount
    getStorageAmount);

our $Version = sprintf("%d.%02d", q$Revision: 3222 $ =~ /(\d+)\.(\d+)/);

# adapted config file parser
sub parseMacroFile {
  my ($file) = @_;
  undef %macro;
  undef %automacro;

  my %block;
  my $tempmacro = 0;
  open FILE, "< $file";
  foreach (<FILE>) {
    next if (/^\s*#/); # skip comments
    s/^\s*//g;         # remove leading whitespaces
    s/\s*[\r\n]?$//g;  # remove trailing whitespaces and eol
    s/  +/ /g;         # trim down spaces
    next unless ($_);

    if (!%block && /{$/) {
      s/\s*{$//;     # remove { at end of line
      my ($key, $value) = $_ =~ /^(.*?) (.*)/;
      if ($key eq 'macro') {
        %block = (name => $value, type => "macro");
        $macro{$value} = [];
      } elsif ($key eq 'automacro') {
        %block = (name => $value, type => "auto");
      }
    } elsif ($block{type} eq "macro") {
      if ($_ eq "}") {
        undef %block;
      } else {
        push(@{$macro{$block{name}}}, $_);
      }
    } elsif ($block{type} eq "auto") {
      if ($_ eq "}") {
        if ($block{loadmacro}) {
          undef $block{loadmacro};
        } else {
          undef %block;
        }
      } elsif ($_ eq "call {") {
        $block{loadmacro} = 1;
        $block{loadmacro_name} = "tempMacro".$tempmacro++;
        $automacro{$block{name}}->{call} = $block{loadmacro_name};
        $macro{$block{loadmacro_name}} = [];
      } elsif ($block{loadmacro}) {
        push(@{$macro{$block{loadmacro_name}}}, $_);
      } else {
        my ($key, $value) = $_ =~ /^(.*?) (.*)/;
        next unless $key;
        if ($key =~ /^(inventory|storage|cart|shop|equipped|var|status|location|set)+$/) {
          push(@{$automacro{$block{name}}->{$key}}, $value);
        } else {
          $automacro{$block{name}}->{$key} = $value;
        }
      }
    }
  }
  close FILE;
}

# command line parser for macro
# returns undef if something went wrong, else the parsed command or "".
sub parseCmd {
  $cvs->debug("parseCmd (@_)", $logfac{function_call_macro});
  my $command = shift;
  return "" unless defined $command;
  while ($command =~ /\$\.?[a-zA-Z]/) {
    $cvs->debug("scanning for variables in $command", $logfac{parser_steps});
    my ($var) = $command =~ /\$(\.?[a-zA-Z][a-zA-Z\d]*)/;
    if (defined $var) {my $tmp = getVar($var);$command =~ s/\$$var/$tmp/g;}
  }
  while ($command =~ /\@/) {
    $cvs->debug("parsing ($command)", $logfac{parser_steps});
    my $ret = "_%_";
    my ($kw, $arg) = $command =~ /\@([a-z]*) +\(([^@]*?)\)/i;
    return $command if (!defined $kw || !defined $arg);
    if ($kw eq 'npc')           {$ret = getnpcID($arg)}
    elsif ($kw eq 'cart')       {$ret = getItemID($arg, \@{$cart{inventory}})}
    elsif ($kw eq 'inventory')  {$ret = getItemID($arg, \@{$char->{inventory}})}
    elsif ($kw eq 'store')      {$ret = getItemID($arg, \@::storeList)}
    elsif ($kw eq 'storage')    {$ret = getStorageID($arg)}
    elsif ($kw eq 'player')     {$ret = getPlayerID($arg, \@::playersID)}
    elsif ($kw eq 'vender')     {$ret = getPlayerID($arg, \@::venderListsID)}
    elsif ($kw eq 'random')     {$ret = getRandom($arg)}
    elsif ($kw eq 'invamount')  {$ret = getInventoryAmount($arg)}
    elsif ($kw eq 'cartamount') {$ret = getCartAmount($arg)}
    elsif ($kw eq 'shopamount') {$ret = getShopAmount($arg)}
    elsif ($kw eq 'storamount') {$ret = getStorageAmount($arg)}
    elsif ($kw eq 'eval')       {$ret = eval($arg)};
    return $command if $ret eq '_%_';
    if (defined $ret) {$arg = quotemeta $arg; $command =~ s/\@$kw +\($arg\)/$ret/g}
    else {error "[macro] command $command failed.\n"; return}
  }
  return $command;
}

1;
