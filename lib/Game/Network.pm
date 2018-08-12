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
sub msg_effects {
    my ($effects) = @_;

    return {
        type        => 'effects',
        replace     => 1,
        effects     => {map {$_->{id} => $_->msg_contents()} @$effects},
    };
}

sub send_ship_position_to {
    my ($ship, $ships) = @_;

    my $msg = $ship->msg();
    for my $whom(@$ships) {
        next unless $whom->{player};

        $whom->{player}->send_msg($msg);
    }
}
sub send_ship_destroyed_to {
    my ($ship, $ships) = @_;

    for my $whom(@$ships) {
        next unless $whom->{player};

        $whom->{player}->send_msg( $ship->msg_destroyed() );
    }
}

sub send_effect_to {
    my ($effect, $ships) = @_;

    my $msg = $effect->msg();
    for my $whom(@$ships) {
        next unless $whom->{player};

        $whom->{player}->send_msg($msg);
    }
}

1;
