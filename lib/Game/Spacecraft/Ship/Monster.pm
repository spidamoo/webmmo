package Game::Spacecraft::Ship::Monster;
use strict;
use warnings;

use parent 'Game::Spacecraft::Ship';

use Game::Tools qw(roll random_from_list);

my %groups = (
    'asteroid' => ['asteroid1'],
);

sub new {
    my ($class, $params) = @_;

    my $self = $class->SUPER::new($params);
    $self->{type} = 'monster';

    if ($self->{group}) {
        $self->{codename} = random_from_list(@{ $groups{ $self->{group} } });
        if ($self->{group} eq 'asteroid') {
            $self->{geometry}{radius} = 64;
        }
    }

    $self->{speed}      = 90;
    $self->{hp}         = 1;
    $self->{max_hp}     = 1;

    return $self;
}

sub init {
    my ($self, $params) = @_;

    if ($params->{drift_direction}) {
        $self->{move} = 1;
        $self->{direction} = $params->{drift_direction};
    }

    $self->update_control();
}

sub update {
    my ($self, $dt) = @_;

    $self->SUPER::update($dt);

    if ($self->{spawned_by} && $self->{spawned_by}{unspawn_on}) {
        my $unspawn_on = $self->{spawned_by}{unspawn_on};
        my $unspawn = 0;
        if (my $location = $unspawn_on->{location}) {
            for my $c(qw(x y)) {
                if ($location->{$c}) {
                    for my $condition(keys %{ $location->{$c} }) {
                        if ($condition eq '>') {
                            if ($self->{$c} > $location->{$c}{$condition}) {
                                $unspawn = 1;
                            }
                        }
                    }
                }
            }
        }

        if ($unspawn) {
            $self->die();
            return;
        }
    }

    if ($self->{group} eq 'asteroid') {
        for my $ship(@{$self->{game}->ships_closeby($self)}) {
            next if $ship->{type} eq 'station';
            next if $ship->{id} eq $self->{id};

            if ( $self->collides($ship) ) {
                $ship->damage(1);
                $self->die();
            }
        }
    }
}

sub die {
    my ($self) = @_;

    $self->SUPER::die();
}

1;