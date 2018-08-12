package Game::Tools;
use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(roll random_from_list);


sub roll {
    my ($pool) = @_;

    $pool =~ s/(\-?\d*)d(\d*)/_dice($1, $2)/eg;
    $pool =~ s/(\-?\d+)\s?\.\.\s?(\-?\d+)/_from_to($1, $2)/eg;
    return eval $pool;
}

sub _dice {
    my ($num, $sides) = @_;
    $num ||= 1;
    $sides ||= 6;

    my $total = 0;
    $total += 1 + int( rand($sides) ) for 1 .. $num;

    return $total;
}

sub _from_to {
    my ($from, $to) = @_;

    return $from + int( rand($to - $from + 1) );
}

sub random_from_list {
    return $_[_from_to(0, $#_)];
}

1;