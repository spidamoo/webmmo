package Game;
use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(game_loop);

use constant {
    MOVE_IDLE   => 0,
    MOVE_R      => 1,
    MOVE_RD     => 2,
    MOVE_D      => 3,
    MOVE_LD     => 4,
    MOVE_L      => 5,
    MOVE_LU     => 6,
    MOVE_U      => 7,
    MOVE_RU     => 8,
};

use Time::HiRes qw(time);
use Data::Dumper;
use Devel::Size qw(total_size);
use Scalar::Util qw(weaken);
use Devel::Cycle;

use Tools::ReusableList;
use Game::Tools qw(roll random_from_list);

use Game::Network;
use Game::Player;
use Game::Spacecraft::Ship;
use Game::Spacecraft::Ship::Monster;
use Game::Spacecraft::Station;
use Game::Effect;

sub DEBUG {
    return $_[0]->{debug};
}

sub new {
    my ($class) = @_;

    my $self = {
        debug   => 1,
        players => {},
        objects => {},
        ships   => {
            space => {},
        },
        effects => {
            space => Tools::ReusableList->new(),
        },
        spawners => {
            space => [
                {
                    group       => 'asteroid',
                    frequency   => 1,
                    spawn_at    => {
                        x  => '500..1000',
                        y  => '-200..-100',
                        da => '-25..25 / 10',
                    },
                    unspawn_on  => {
                        location => {y => {'>' => 1000} },
                    },
                    init        => {
                        drift_direction => MOVE_D,
                    },
                    spawned     => Tools::ReusableList->new(),
                },
            ],
        },
    };

    $self->{ships}{space}{station} = Game::Spacecraft::Station->new({
        id          => 'station',
        type        => 'station',
        x           => 300,
        y           => 300,
        da          => 0.1,
        geometry => {
            radius => 100,
        },
    });

    return bless $self, $class;
}

sub step {
    my ($self, $dt) = @_;
    for my $zone(keys %{ $self->{ships} }) {
        for my $ship(values %{ $self->{ships}{$zone} }) {
            $ship->update($dt);
        }
        for my $ship(values %{ $self->{ships}{$zone} }) {
            $self->destroy_ship($ship) if $ship->{dead};
        }
        for my $effect(@{$self->{effects}{$zone}->aref()}) {
            next unless $effect;
            $effect->update($dt);
        }
        for my $effect(@{$self->{effects}{$zone}->aref()}) {
            next unless $effect;
            $self->remove_effect($effect, notify => $effect->{dead} == 2) if $effect->{dead};
        }

        for my $i(0 .. $#{ $self->{spawners}{$zone} }) {
            my $spawner = $self->{spawners}{$zone}[$i];
            $spawner->{time} //= $spawner->{frequency};
            $spawner->{time} -= $dt;
            while ($spawner->{time} < 0) {
                $spawner->{time} += $spawner->{frequency};

                my $spawned = Game::Spacecraft::Ship::Monster->new({
                    game        => $self,
                    group       => $spawner->{group},
                    spawned_by  => $spawner,
                });
                my $id = $spawner->{spawned}->add($spawned);
                # weaken($spawner->{spawned}{_array}[$id]);
                $spawned->{id} = sprintf('monster_%d_%d', $i, $id);

                $spawned->{$_} = roll($spawner->{spawn_at}{$_}) for keys(%{ $spawner->{spawn_at} });

                $self->spawn_ship($zone, $spawned, $spawned->{x} // 0, $spawned->{y} // 0);
                $spawned->init($spawner->{init});
            }
        }
    }
}

sub spawn_ship {
    my ($self, $zone, $ship, $x, $y) = @_;

    $ship->{zone}       = $zone;
    $ship->{x}          = $x;
    $ship->{y}          = $y;
    $ship->{dx}         = 0;
    $ship->{dy}         = 0;
    $ship->{move}       = 0;
    $ship->{direction}  = MOVE_R;;
    $self->{ships}{$zone}->{ $ship->{id} } = $ship;
    # weaken($self->{ships}{$zone}->{ $ship->{id} });

    # printf STDERR "spawn ship <%s> <%d> <%dkB>\n", $ship->{id}, scalar(keys %{ $self->{ships}{space} }), total_size($self) / 1024;

    if ($ship->{player}) {
        $ship->{player}->send_msg( Game::Network::msg_zone($zone) );
        $ship->{player}->send_msg( Game::Network::msg_objects([values %{ $self->{objects}{$zone} }])       );
        $ship->{player}->send_msg( Game::Network::msg_ships  ([values %{ $self->{ships}  {$zone} }])       );
        $ship->{player}->send_msg( Game::Network::msg_effects(         @{$self->{effects}{$zone}->aref()}) );
        $ship->{player}->send_msg( $ship->msg_inventory() );
        $ship->{player}->send_msg( $ship->msg_equip()     );
        $ship->{player}->send_msg( $ship->msg_skills()    );
    }
    Game::Network::send_ship_position_to($ship, [values %{ $self->{ships}{$zone} }]);

    return $ship;
}

sub destroy_ship {
    my ($self, $ship) = @_;
    my $zone = $ship->{zone};
    my $id   = $ship->{id};
    my (undef, undef, $index) = split('_', $id);
    Game::Network::send_ship_destroyed_to($ship, [values %{ $self->{ships}{$zone} }]);
    delete $self->{ships}{$zone}{$id};
    if ($ship->{spawned_by}) {
        $ship->{spawned_by}{spawned}->remove($index);
    }

    # printf STDERR "destroy ship <%s> <%d> <%dkB>\n",
    #     $id, scalar(keys %{ $self->{ships}{space} }), total_size($self) / 1024;
    # find_cycle($self, sub {print STDERR Dumper(\@_)});
}

sub ships_closeby {
    my ($self, $object) = @_;

    # print STDERR Dumper($ship->{zone}, $self->{ships}{ $ship->{zone} });
    return [values %{ $self->{ships}{ $object->{zone} } }];
}

sub on_ship_control_update {
    my ($self, $ship) = @_;
    Game::Network::send_ship_position_to($ship, [values %{ $self->{ships}{ $ship->{zone} } }]);
}

sub add_player {
    my ($self, $client_id, $handle) = @_;
    my $ship_id = 'player_' . $client_id;

    $self->{players}{$client_id} = Game::Player->new({
        id     => $client_id,
        handle => $handle,
        game   => $self,
    });
    $self->{players}{$client_id}{ship} = Game::Spacecraft::Ship->new({
        player  => $self->{players}{$client_id},
        id      => $ship_id,
        game    => $self,
    });
    $self->{players}{$client_id}->send_msg({
        type => 'id',
        id   => $client_id,
    });

    $self->spawn_ship('space', $self->{players}{$client_id}->{ship}, 100, 100);

    return $self->{players}{$client_id};
}
sub remove_player {
    my ($self, $client_id) = @_;

    if ($self->{players}{$client_id}{ship}{zone} eq 'space') {
        $self->destroy_ship($self->{players}{$client_id}{ship});
    }
    delete $self->{players}{$client_id};
}

sub add_effect {
    my ($self, $effect, %params) = @_;
    my $zone = $params{zone};
    $effect->{id} = $self->{effects}{$zone}->add($effect);
    $effect->{game} = $self;
    $effect->{zone} = $zone;
    Game::Network::send_effect_to($effect, [values %{ $self->{ships}{$zone} }]);
}
sub remove_effect {
    my ($self, $effect, %params) = @_;

    my $zone = $effect->{zone};
    if ($params{notify}) {
        Game::Network::send_effect_destroyed_to($effect, [values %{ $self->{ships}{$zone} }]);
    }
    $self->{effects}{$zone}->remove($effect->{id});
}

sub process_message {
    my ($self, $client_id, $message) = @_;

    my $player = $self->{players}{$client_id};
    my $ship   = $player->{ship};
    my $zone   = $ship->{zone};

    if ($message->{type} eq 'move') {
        return unless defined $message->{move};
        if ($player->{ship}{zone} eq 'space') {
            my $ship = $player->{ship};
            $ship->update_control($message);
        }
    }
    elsif ($message->{type} eq 'dock') {
        return unless defined $message->{to};
        my $station = $self->{ships}{$zone}->{ $message->{to} };
        return unless $station && $station->{type} eq 'station';

        return unless $ship->collides($station);

        $ship->dock($station);
        $player->send_msg( $station->msg_schemas() );
    }
    elsif ($message->{type} eq 'undock') {
        $ship->undock();
    }
    elsif ($message->{type} eq 'craft') {
        my $station = $ship->{docked};
        return unless $station && $station->{schemas}[$message->{what}];
        my $item = Game::Item::craft($station->{schemas}[$message->{what}], $ship);
        if ($item) {
            $ship->add_item($item);
            $player->send_msg( $ship->msg_inventory() );
        }
    }
    elsif ($message->{type} eq 'use') {
        my $item = $ship->{inventory}[$message->{what}];
        return unless $item;

        if (Game::Item::EQUIPABLE_TYPES->{ $item->{type} }) {
            return unless $ship->{docked};
            $ship->equip($message->{what});
            $player->send_msg( $ship->msg_inventory() );
            $player->send_msg( $ship->msg_equip() );
            $player->send_msg( $ship->msg_skills() );
        }
    }
    elsif ($message->{type} eq 'unequip') {
        return unless $ship->{docked};
        $ship->unequip($message->{what});
        $player->send_msg( $ship->msg_inventory() );
        $player->send_msg( $ship->msg_equip() );
        $player->send_msg( $ship->msg_skills() );
    }
    elsif ($message->{type} eq 'skill') {
        $ship->use_skill($message->{what}, $message->{params});
    }
}

1;
