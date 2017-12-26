#!/usr/bin/env perl

use strict;
use warnings;

use lib 'lib';

use Plack::Runner;

use Plack::Builder;
use AnyMQ;
use AnyEvent;
use Data::Dumper;
use Time::HiRes qw(time);
use feature 'say';

my %players;
my $dt = 3;
my $now = time();
my $ticker = AnyEvent->timer(after => $dt, interval => $dt, cb => sub {
    for my $player(values %players) {
        # print STDERR 'ship ' . Data::Dumper::Dumper($player->{ship});

        $player->{ship}{x} += $player->{ship}{dx} * $dt;
        $player->{ship}{y} += $player->{ship}{dy} * $dt;

        $player->{ship}{dx} += $player->{ship}{a} * cos($player->{ship}{r}) * $dt;
        $player->{ship}{dy} += $player->{ship}{a} * sin($player->{ship}{r}) * $dt;

        $player->{ship}{dx} *= $player->{ship}{i};
        $player->{ship}{dy} *= $player->{ship}{i};

        $player->{ship}{dx} = 0 if $player->{ship}{dx} < 1 && $player->{ship}{dx} > -1;
        $player->{ship}{dy} = 0 if $player->{ship}{dy} < 1 && $player->{ship}{dy} > -1;

        # print STDERR 'ship2 ' . Data::Dumper::Dumper($player->{ship});
    }
    my $ships = { map { $_ => $players{$_}->{ship} } keys %players};
    # say time() - $now;
    $now = time();
    # print STDERR Data::Dumper::Dumper($ships);
    for my $player(values %players) {
        $player->{handle}->send_msg({
            type  => 'tick',
            ships => $ships,
        });
    }
    # say 'tick';
});

my $bus = AnyMQ->new;
my $topic = $bus->topic('demo');
 
my $app = builder {
    mount '/_hippie' => builder {
        enable "+Web::Hippie";

        sub {
            my $env = shift;
            my $client_id = $env->{'hippie.client_id'}; # client id
            my $handle    = $env->{'hippie.handle'};
            my $path      = $env->{PATH_INFO};

            say "$path $client_id";

            if ($path eq '/init') {
                $players{$client_id} = {
                    handle => $handle,
                    ship   => {
                        x  => 100,
                        y  => 100,
                        r  => 0,
                        a  => 0,
                        dx => 0,
                        dy => 0,
                        i  => 0.2,
                    }
                };
                $handle->send_msg({
                    type => 'id',
                    id   => $client_id,
                });
            }
            elsif ($path eq '/message') {
                my $message = $env->{'hippie.message'};
                # print STDERR Dumper($message);
                if ($message->{type} eq 'control') {
                    $players{$client_id}->{ship}{r} = $message->{control}{r};
                    $players{$client_id}->{ship}{a} = int($message->{control}{a}) * 100;
                }
            }
            elsif ($path eq '/error') {
                delete $players{$client_id};
            }
            elsif ($path eq '/disconnect') {
                delete $players{$client_id};
            }

            # print Dumper({ map {$_ => $env->{$_}} grep {$_ =~ /hippie/} keys %$env });
        }
    };
    mount '/' => sub {
        my $env = shift;

        if ($env->{PATH_INFO} eq '/') {
            open my $fh, 'index.html';
            return [
                200,
                ['Content-Type' => 'text/html; charset=utf-8'],
                $fh
            ];
        }
        else {
            return [
                404,
                ['Content-Type' => 'text/plain; charset=utf-8'],
                ['Здесь рыбы нет']
            ];
        }

    };
};

my $runner = Plack::Runner->new;
$runner->parse_options(@ARGV);
$runner->run($app);

