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

use Game::Network;
use Game::Ship;
use Game::Player;

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
    };

    $self->{ships}{space}{station} = Game::Ship->new(
        id          => 'station',
        type        => 'station',
        x           => 300,
        y           => 300,
        da          => 0.1,
        # dock        => {
        #     geometry => {
        #         radius => 100,
        #     },
        #     to       => 'station',
        #     at       => [100, 100],
        # },
    );

    return bless $self, $class;
}

sub step {
    my ($self, $dt) = @_;
    for my $zone(keys %{ $self->{ships} }) {
        for my $ship(values %{ $self->{ships}{$zone} }) {
            $ship->update($dt);
        }
    }

    # $now = time();
}

sub spawn_ship {
    my ($self, $zone, $ship, $x, $y) = @_;

    $ship->{x}          = $x;
    $ship->{y}          = $y;
    $ship->{dx}         = 0;
    $ship->{dy}         = 0;
    $ship->{move}       = 0;
    $ship->{direction}  = MOVE_R;;
    $self->{ships}{$zone}->{ $ship->{id} } = $ship;

    if ($ship->{player}) {
        $ship->{player}{zone} = $zone;
        $ship->{player}->send_msg( Game::Network::msg_zone($zone) );
        $ship->{player}->send_msg( Game::Network::msg_objects([values %{ $self->{objects}{$zone} }]) );
        $ship->{player}->send_msg( Game::Network::msg_ships([values %{ $self->{ships}{$zone} }]) );
    }
    Game::Network::send_ship_position_to($ship, [values %{ $self->{ships}{$zone} }]);

    return $ship;
}


sub destroy_ship {
    my ($self, $zone, $id) = @_;
    Game::Network::send_ship_destroyed_to($self->{ships}{$zone}{$id}, [values %{ $self->{ships}{$zone} }]);
    delete $self->{ships}{$zone}{$id};
}

sub add_player {
    my ($self, $client_id, $handle) = @_;
    my $ship_id = 'player_' . $client_id;

    $self->{players}{$client_id} = Game::Player->new(
        id     => $client_id,
        handle => $handle,
        zone   => 'space',
        game   => $self,
    );
    $self->{players}{$client_id}{ship} = Game::Ship->new(
        player  => $self->{players}{$client_id},
        id      => $ship_id,
        game    => $self,
    );
    $self->{players}{$client_id}->send_msg({
        type => 'id',
        id   => $client_id,
    });

    $self->spawn_ship('space', $self->{players}{$client_id}->{ship}, 100, 100);

    return $self->{players}{$client_id};
}
sub remove_player {
    my ($self, $client_id) = @_;

    if ($self->{players}{$client_id}{zone} eq 'space') {
        $self->destroy_ship($self->{players}{$client_id}{zone}, 'player_' . $client_id);
    }
    delete $self->{players}{$client_id};
}

sub process_message {
    my ($self, $client_id, $message) = @_;

    if ($message->{type} eq 'move') {
        return unless defined $message->{move};
        my $player = $self->{players}{$client_id};
        if ($player->{zone} eq 'space') {
            my $ship = $player->{ship};
            if ($message->{move} == MOVE_IDLE) {
                $ship->{move} = 0;
            }
            else {
                $ship->{move} = 1;
                $ship->{direction} = int($message->{move});
            }
            $ship->update_control();
            Game::Network::send_ship_position_to($ship, [values %{ $self->{ships}{ $player->{zone} } }]);
        }
    }
    elsif ($message->{type} eq 'dock') {
        return unless defined $message->{to};
        my $to = $self->{ships}{ $self->{players}{$client_id}->{zone} }->{ $message->{to} };
        return unless $to && $to->{dock};

        my $ship = $self->{players}{$client_id}->{ship};
        my $dx = $ship->{x} - $to->{x};
        my $dy = $ship->{y} - $to->{y};
        my $distance = sqrt($dx ** 2 + $dy ** 2);
        return unless $distance < $to->{dock}{geometry}{radius};
    }
}

1;
