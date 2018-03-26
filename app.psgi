#!/usr/bin/env perl

use strict;
use warnings;

use lib 'lib';
use feature 'say';

use Plack::Runner;
use Plack::Builder;
use Web::Hippie;

use AnyEvent;
use Time::HiRes qw(time);
use IO::All;
# use Template;

# TODO: move to the tools pm?
use constant DEBUG => $ENV{DEBUG} // $ENV{PLACK_ENV} eq 'development';

use if DEBUG, 'Data::Dumper';

# TODO: move to the game pm
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


my %players;
my %ships = (
    space => {
        station => {
            type        => 'station',
            x           => 300,
            y           => 300,
            da          => 0.1,
            dock        => {
                geometry => {
                    radius => 100,
                },
                to       => 'station',
                at       => [100, 100],
            },
        },
    },
);
my %people = (
    station => {},
);
my %objects = (
    station => [
        { type => 'floor', geometry => {left => 0, y => 200, right => 1000} }
    ],
);

my $dt = 0.03;
my $now = time();
my $ticker = AE::timer($dt, $dt, sub {
    for my $zone(keys %ships) {
        for my $ship(values %{ $ships{$zone} }) {
            for (qw(x y dx dy)) {
                $ship->{$_} = 0 unless defined $ship->{$_};
            }

            $ship->{x} += $ship->{dx} * $dt;
            $ship->{y} += $ship->{dy} * $dt;

            if (defined $ship->{da}) {
                $ship->{a} = 0 unless defined $ship->{a};
                $ship->{a} += $ship->{da} * $dt;
            }
        }
    }
    for my $zone(keys %people) {
        while (my ($id, $person) = each %{ $people{$zone} }) {
            for (qw(x y dx dy)) {
                $person->{$_} = 0 unless defined $person->{$_};
            }

            my $update = 0;

            if (defined $person->{standing}) {
                my $object = $objects{$zone}->[$person->{standing}];
                if ($person->{x} < $object->{geometry}{left} || $person->{x} > $object->{geometry}{right}) {
                    $person->{standing} = undef;
                }
            }
            else {
                $person->{dy} += 500 * $dt;
                my $i = 0;
                for my $object(@{ $objects{$zone} }) {
                    if ($object->{type} eq 'floor') {
                        if (
                            $person->{dy} > 0 &&
                            $person->{x} > $object->{geometry}{left} && $person->{x} < $object->{geometry}{right} &&
                            $person->{y} > $object->{geometry}{y} && $person->{y} < $object->{geometry}{y} + 10
                        ) {
                            $update = 1;
                            $person->{dy} = 0;
                            $person->{y}  = $object->{geometry}{y};
                            $person->{standing} = $i;
                        }
                    }
                    $i++;
                }
            }

            $person->{x} += $person->{dx} * $dt;
            $person->{y} += $person->{dy} * $dt;

            if ($update) {
                send_person_position($zone, $id);
            }
        }
    }

    # say time() - $now;
    $now = time();
    # print STDERR Data::Dumper::Dumper($ships);
    # for my $player(values %players) {
        # $player->{handle}->send_msg({
        #     type  => 'tick',
        #     ships => $ships,
        # });
    # }
});

sub update_ship {
    my ($ship) = @_;

    my $dx = 0;
    my $dy = 0;
    if ($ship->{move}) {
        if ($ship->{direction} == MOVE_R) {
            $dx = 1;
            $dy = 0;
        }
        elsif ($ship->{direction} == MOVE_RD) {
            $dx = .707;
            $dy = .707;
        }
        elsif ($ship->{direction} == MOVE_D) {
            $dx = 0;
            $dy = 1;
        }
        elsif ($ship->{direction} == MOVE_LD) {
            $dx = -.707;
            $dy =  .707;
        }
        elsif ($ship->{direction} == MOVE_L) {
            $dx = -1;
            $dy =  0;
        }
        elsif ($ship->{direction} == MOVE_LU) {
            $dx = -.707;
            $dy = -.707;
        }
        elsif ($ship->{direction} == MOVE_U) {
            $dx =  0;
            $dy = -1;
        }
        elsif ($ship->{direction} == MOVE_RU) {
            $dx =  .707;
            $dy = -.707;
        }
    }

    my $speed = 100;
    $ship->{dx} = $speed * $dx;
    $ship->{dy} = $speed * $dy;

    # print STDERR Dumper($ship, $dx, $dy) if DEBUG;
}
sub update_person {
    my ($person) = @_;

    my $speed = 70;
    if ($person->{move}) {
        if ($person->{direction} == MOVE_R) {
            $person->{dx} = $speed * 1;
        }
        elsif ($person->{direction} == MOVE_L) {
            $person->{dx} = $speed * -1;
        }
    }
    else {
        $person->{dx} = 0;
    }

    if ($person->{jump} && defined $person->{standing}) {
        $person->{dy} = -200;
        $person->{standing} = undef;
        $person->{jump} = 0;
    }
}

sub add_player {
    my ($client_id, $handle) = @_;

    $players{$client_id} = {
        id     => $client_id,
        handle => $handle,
        zone   => 'space',
    };
    $players{$client_id}->{ship}    = { player => $players{$client_id} };
    $players{$client_id}->{person}  = { player => $players{$client_id} };

    $handle->send_msg({
        type => 'id',
        id   => $client_id,
    });

    return $players{$client_id};
}
sub remove_player {
    my ($client_id) = @_;

    if ($players{$client_id}->{zone} eq 'space') {
        destroy_ship($players{$client_id}->{zone}, 'player_' . $client_id);
    }
    elsif ($players{$client_id}->{zone} eq 'station') {
        destroy_person($players{$client_id}->{zone}, 'player_' . $client_id);
    }
    delete $players{$client_id};
}
sub spawn_ship {
    my ($zone, $id, $ship, $x, $y) = @_;

    $ship->{x}          = $x;
    $ship->{y}          = $y;
    $ship->{dx}         = 0;
    $ship->{dy}         = 0;
    $ship->{move}       = 0;
    $ship->{direction}  = MOVE_R;;
    $ships{$zone}->{$id} = $ship;

    if ($ship->{player}) {
        $ship->{player}{zone} = $zone;
        $ship->{player}{handle}->send_msg( msg_zone($zone) );
        $ship->{player}{handle}->send_msg( msg_objects($zone) );
        $ship->{player}{handle}->send_msg( msg_ships_list($zone) );
    }
    send_ship_position($zone, $id);

    return $ship;
}
sub destroy_ship {
    my ($zone, $id) = @_;
    delete $ships{$zone}->{$id};
    send_ship_destroyed($zone, $id);
}
sub spawn_person {
    my ($zone, $id, $person, $x, $y) = @_;

    $person->{x}          = $x;
    $person->{y}          = $y;
    $person->{dx}         = 0;
    $person->{dy}         = 0;
    $person->{move}       = 0;
    $person->{direction}  = MOVE_R;;
    $people{$zone}->{$id} = $person;

    if ($person->{player}) {
        $person->{player}{zone} = $zone;
        $person->{player}{handle}->send_msg( msg_zone($zone) );
        $person->{player}{handle}->send_msg( msg_objects($zone) );
        $person->{player}{handle}->send_msg( msg_people_list($zone) );
    }
    send_person_position($zone, $id);

    return $person;
}
sub destroy_person {
    my ($zone, $id) = @_;
    delete $people{$zone}->{$id};
    send_person_destroyed($zone, $id);
}

sub send_ship_position {
    my ($zone, $id) = @_;

    for my $ship(values %{ $ships{$zone} }) {
        # next if $player->{id} eq $client_id;
        next unless $ship->{player};
        $ship->{player}{handle}->send_msg( msg_ship($zone, $id) );
    }
}
sub send_ship_destroyed {
    my ($zone, $id) = @_;

    for my $ship(values %{ $ships{$zone} }) {
        next unless $ship->{player};
        $ship->{player}{handle}->send_msg( msg_ship_destroyed($id) );
    }
}
sub send_person_position {
    my ($zone, $id) = @_;

    for my $person(values %{ $people{$zone} }) {
        # next if $player->{id} eq $client_id;
        next unless $person->{player};
        $person->{player}{handle}->send_msg( msg_person($zone, $id) );
    }
}
sub send_person_destroyed {
    my ($zone, $id) = @_;

    for my $person(values %{ $people{$zone} }) {
        next unless $person->{player};
        $person->{player}{handle}->send_msg( msg_ship_destroyed($id) );
    }
}

sub msg_zone {
    my ($zone) = @_;
    return {
        type  => 'zone',
        zone  => $zone,
    };
}
sub msg_ship {
    my ($zone, $id) = @_;
    return {
        type  => 'ships',
        ships => { $id => { map { $_ => $ships{$zone}->{$id}{$_} } qw(x y dx dy a da move direction type) } },
    };
}
sub msg_ship_destroyed {
    my ($id) = @_;
    return {
        type    => 'ship_destroyed',
        id      => $id,
    };
}
sub msg_ships_list {
    my ($zone) = @_;

    my %result;
    while (my ($id, $ship)= each %{ $ships{$zone} }) {
        $result{$id} = { map { $_ => $ship->{$_} } qw(x y dx dy a da move direction type) };
    }
    return {
        type        => 'ships',
        replace     => 1,
        ships       => \%result,
    };
}
sub msg_person {
    my ($zone, $id) = @_;
    return {
        type  => 'people',
        people => { $id => { map { $_ => $people{$zone}->{$id}{$_} } qw(x y dx dy move direction type) } },
    };
}
sub msg_person_destroyed {
    my ($id) = @_;
    return {
        type    => 'person_destroyed',
        id      => $id,
    };
}
sub msg_people_list {
    my ($zone) = @_;

    my %result;
    while (my ($id, $person)= each %{ $people{$zone} }) {
        $result{$id} = { map { $_ => $person->{$_} } qw(x y dx dy a da move direction type) };
    }
    return {
        type        => 'people',
        replace     => 1,
        people      => \%result,
    };
}
sub msg_objects {
    my ($zone) = @_;

    my @result;
    for my $object(@{ $objects{$zone} }) {
        push @result, { map { $_ => $object->{$_} } qw(type geometry) };
    }
    return {
        type        => 'objects',
        objects     => \@result,
    };
}

my %static_files = (
    '/js/easeljs-0.8.2.min.js' => 0,
    '/js/jquery-3.2.1.min.js'  => 0,
    '/'                        => {fn => 'index.html', headers => ['Content-Type' => 'text/html; charset=utf-8']},
);

my %html = (
    'index._.html' => 'index.html',
);
if (DEBUG) {
    # my $tt = Template->new({});
    while (my ($from, $to) = each %html) {
        # $tt->process($from, undef, $to);
        my $text = io($from)->slurp();
        $text =~ s/\[%(.+?)%\]/eval $1/eg;
        io($to)->print($text);
    }
}
 
my $app = builder {
    mount '/_hippie' => builder {
        enable "+Web::Hippie";

        sub {
            my $env = shift;
            my $client_id = $env->{'hippie.client_id'}; # client id
            my $handle    = $env->{'hippie.handle'};
            my $path      = $env->{PATH_INFO};

            # say "$path $client_id";

            if ($path eq '/init') {
                my $player = add_player($client_id, $handle);
                spawn_ship('space', 'player_' . $client_id, $player->{ship}, 100, 100);
            }
            elsif ($path eq '/message') {
                my $messages = $env->{'hippie.message'};
                $messages = [$messages] unless (ref($messages) eq 'ARRAY');
                for my $message(@$messages) {
                    # print STDERR Dumper($message) if DEBUG;
                    if ($message->{type} eq 'move') {
                        next unless defined $message->{move};
                        if ($players{$client_id}->{zone} eq 'space') {
                            if ($message->{move} == MOVE_IDLE) {
                                $players{$client_id}->{ship}{move} = 0;
                            }
                            else {
                                $players{$client_id}->{ship}{move} = 1;
                                $players{$client_id}->{ship}{direction} = int($message->{move});
                            }
                            update_ship($players{$client_id}->{ship});
                            send_ship_position($players{$client_id}->{zone}, 'player_' . $client_id);
                        }
                        elsif ($players{$client_id}->{zone} eq 'station') {
                            if ($message->{move} == MOVE_IDLE) {
                                $players{$client_id}->{person}{move} = 0;
                            }
                            elsif ($message->{move} == MOVE_R || $message->{move} == MOVE_L) {
                                $players{$client_id}->{person}{move} = 1;
                                $players{$client_id}->{person}{direction} = int($message->{move});
                            }
                            elsif ($message->{move} == MOVE_U) {
                                $players{$client_id}->{person}{jump} = 1;
                            }
                            update_person($players{$client_id}->{person});
                            send_person_position($players{$client_id}->{zone}, 'player_' . $client_id);
                        }
                    }
                    elsif ($message->{type} eq 'dock') {
                        next unless defined $message->{to};
                        my $to = $ships{ $players{$client_id}->{zone} }->{ $message->{to} };
                        next unless $to && $to->{dock};
                        my $dx = $players{$client_id}->{ship}{x} - $to->{x};
                        my $dy = $players{$client_id}->{ship}{y} - $to->{y};
                        my $distance = sqrt($dx ** 2 + $dy ** 2);
                        next unless $distance < $to->{dock}{geometry}{radius};
                        destroy_ship($players{$client_id}->{zone}, 'player_' . $client_id);
                        spawn_person($to->{dock}{to}, 'player_' . $client_id, $players{$client_id}->{person}, @{ $to->{dock}{at} });
                    }
                }
            }
            elsif ($path eq '/error') {
                remove_player($client_id);
            }
            elsif ($path eq '/disconnect') {
                remove_player($client_id);
            }

            # print Dumper({ map {$_ => $env->{$_}} grep {$_ =~ /hippie/} keys %$env });
        }
    };
    mount '/' => sub {
        my $env = shift;

        if (exists $static_files{ $env->{PATH_INFO} }) {
            my $fn = $static_files{ $env->{PATH_INFO} } ? $static_files{ $env->{PATH_INFO} }->{fn} : './' . $env->{PATH_INFO};
            my $headers = $static_files{ $env->{PATH_INFO} } ? $static_files{ $env->{PATH_INFO} }->{headers} : [];
            open my $fh, '<' . $fn;
            return [200, $headers, $fh];
        }

        return [
            404,
            ['Content-Type' => 'text/plain; charset=utf-8'],
            ['Здесь рыбы нет']
        ];
    };
};

my $runner = Plack::Runner->new;
$runner->parse_options(@ARGV);
$runner->run($app);

