package Game::Ship;
use strict;
use warnings;

sub new {
    my ($class, %params) = @_;

    return bless {%params}, $class;
}

sub update_control {
    my ($ship) = @_;

    my $dx = 0;
    my $dy = 0;
    if ($ship->{move}) {
        if ($ship->{direction} == Game::MOVE_R) {
            $dx = 1;
            $dy = 0;
        }
        elsif ($ship->{direction} == Game::MOVE_RD) {
            $dx = .707;
            $dy = .707;
        }
        elsif ($ship->{direction} == Game::MOVE_D) {
            $dx = 0;
            $dy = 1;
        }
        elsif ($ship->{direction} == Game::MOVE_LD) {
            $dx = -.707;
            $dy =  .707;
        }
        elsif ($ship->{direction} == Game::MOVE_L) {
            $dx = -1;
            $dy =  0;
        }
        elsif ($ship->{direction} == Game::MOVE_LU) {
            $dx = -.707;
            $dy = -.707;
        }
        elsif ($ship->{direction} == Game::MOVE_U) {
            $dx =  0;
            $dy = -1;
        }
        elsif ($ship->{direction} == Game::MOVE_RU) {
            $dx =  .707;
            $dy = -.707;
        }
    }

    my $speed = 100;
    $ship->{dx} = $speed * $dx;
    $ship->{dy} = $speed * $dy;

    print STDERR Dumper($ship, $dx, $dy) if Game::DEBUG();
}

sub update {
    my ($self, $dt) = @_;

    for (qw(x y dx dy)) {
        $self->{$_} = 0 unless defined $self->{$_};
    }

    $self->{x} += $self->{dx} * $dt;
    $self->{y} += $self->{dy} * $dt;

    if (defined $self->{da}) {
        $self->{a} = 0 unless defined $self->{a};
        $self->{a} += $self->{da} * $dt;
    }
}

sub msg_contents {
    return { map { $_ => $_[0]->{$_} } qw(x y dx dy a da move direction type) };
}

sub msg {
    return {
        type  => 'ships',
        ships => { $_[0]->{id} => $_[0]->msg_contents() },
    }
}

sub msg_destroyed {
    return {
        type    => 'ship_destroyed',
        id      => $_[0]->{id},
    };
}

1;
