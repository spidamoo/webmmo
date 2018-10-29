package Game::Spacecraft;
use strict;
use warnings;

use Scalar::Util qw(weaken);

use Game::Item;

sub new {
    my ($class, $params) = @_;

    my $self = bless $params, $class;
    $self->{geometry} //= {radius => 10};
    # weaken($self->{game});
    # weaken($self->{player})     if $self->{player};
    # weaken($self->{spawned_by}) if $self->{spawned_by};

    return $self;
}

sub update_control {
    my ($self, $control) = @_;

    my $dx = 0;
    my $dy = 0;

    if (!$self->{docked}) {
        if ($control) {
            if ($control->{move} == Game::MOVE_IDLE) {
                $self->{move} = 0;
            }
            else {
                $self->{move} = 1;
                $self->{direction} = int($control->{move});
            }
        }

        if ($self->{move}) {
            if ($self->{direction} == Game::MOVE_R) {
                $dx = 1;
                $dy = 0;
            }
            elsif ($self->{direction} == Game::MOVE_RD) {
                $dx = .707;
                $dy = .707;
            }
            elsif ($self->{direction} == Game::MOVE_D) {
                $dx = 0;
                $dy = 1;
            }
            elsif ($self->{direction} == Game::MOVE_LD) {
                $dx = -.707;
                $dy =  .707;
            }
            elsif ($self->{direction} == Game::MOVE_L) {
                $dx = -1;
                $dy =  0;
            }
            elsif ($self->{direction} == Game::MOVE_LU) {
                $dx = -.707;
                $dy = -.707;
            }
            elsif ($self->{direction} == Game::MOVE_U) {
                $dx =  0;
                $dy = -1;
            }
            elsif ($self->{direction} == Game::MOVE_RU) {
                $dx =  .707;
                $dy = -.707;
            }
        }
    }

    my $speed = $self->{speed};
    $self->{dx} = $speed * $dx;
    $self->{dy} = $speed * $dy;

    $self->{game}->on_ship_control_update($self);
}

sub update {
    my ($self, $dt) = @_;

    $self->{$_} //= 0 for qw(x y dx dy);

    $self->{x} += $self->{dx} * $dt;
    $self->{y} += $self->{dy} * $dt;

    if (defined $self->{da}) {
        $self->{a} = 0 unless defined $self->{a};
        $self->{a} += $self->{da} * $dt;
    }
}

sub collides {
    my ($self, $other) = @_;

    my $dx = $self->{x} - $other->{x};
    my $dy = $self->{y} - $other->{y};
    my $distance = sqrt($dx ** 2 + $dy ** 2);

    return $distance < ($self->{geometry}{radius} + $other->{geometry}{radius});
}

sub msg_contents {
    my ($self) = @_;
    return {
        ( map { $_ => $self->{$_} } qw(x y dx dy a da move direction type codename) ),
    };
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
