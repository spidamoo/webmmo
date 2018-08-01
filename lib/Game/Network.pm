package Game::Network;
use strict;
use warnings;

sub msg_zone {
    my ($zone) = @_;
    return {
        type  => 'zone',
        zone  => $zone,
    };
}

sub msg_ships {
    my ($ships) = @_;

    return {
        type        => 'ships',
        replace     => 1,
        ships       => {map {$_->{id} => $_->msg_contents()} @$ships},
    };
}
sub msg_objects {
    my ($objects) = @_;

    return {
        type        => 'objects',
        objects     => [map {$_->{id} => $_->msg_contents()} @$objects],
    };
}

sub send_ship_position_to {
    my ($ship, $ships) = @_;

    for my $whom(@$ships) {
        next unless $whom->{player};

        $whom->{player}->send_msg( $ship->msg() );
    }
}
sub send_ship_destroyed_to {
    my ($ship, $ships) = @_;

    for my $whom(@$ships) {
        next unless $whom->{player};

        $whom->{player}->send_msg( $ship->msg_destroyed() );
    }
}

1;
