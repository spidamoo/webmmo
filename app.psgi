#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use feature 'say';

use Plack::Runner;
use Plack::Builder;
use Web::Hippie;

use AnyEvent;
use Time::HiRes qw(time);
use IO::All;
# use Template;

use Game;

use constant PLACK_ENV => $ENV{PLACK_ENV} || 'development'; # this is not accurate as PLACK_ENV can be later affected by -E arg
use constant DEBUG     => $ENV{DEBUG}     // PLACK_ENV eq 'development';

printf "running in %s mode\n", PLACK_ENV;

use if DEBUG, 'Data::Dumper';

my %static_files = (
    '/'                        => {fn => 'index.html', headers => ['Content-Type' => 'text/html; charset=utf-8']},
    '/js/easeljs-0.8.2.min.js' => 0,
    '/js/jquery-3.2.1.min.js'  => 0,
    '/js/Control.js'           => 0,
    '/js/Game.js'              => 0,
    '/js/Map.js'               => 0,
    '/js/Network.js'           => 0,
    '/js/Ship.js'              => 0,
    '/js/Effect.js'         => 0,
    '/js/Interface.js'         => 0,

    '/css/interface.css'       => 0,

    '/img/items/iron.png'           => 0,
    '/img/items/kinetic_gun.png'    => 0,

    '/img/skills/shoot.png'         => 0,

    '/img/monsters/asteroid1.png'   => 0,
);

my %html = (
    'js/Control._.js'   => 'js/Control.js',
    'index._.html'      => 'index.html',
);
if (PLACK_ENV eq 'development') {
    # my $tt = Template->new({});
    while (my ($from, $to) = each %html) {
        # $tt->process($from, undef, $to);
        my $text = io($from)->slurp();
        $text =~ s/\[%(.+?)%\]/eval $1/eg;
        io($to)->print($text);
    }
}

my $game = Game->new();

my $dt = 0.03;
my $now = time();
my $ticker = AE::timer($dt, $dt, sub {
    $game->step($dt);
});


my $app = builder {
    mount '/_hippie' => builder {
        enable "+Web::Hippie";

        sub {
            my $env = shift;
            my $client_id = $env->{'hippie.client_id'};
            my $handle    = $env->{'hippie.handle'};
            my $path      = $env->{PATH_INFO};

            if ($path eq '/init') {
                $game->add_player($client_id, $handle);
            }
            elsif ($path eq '/message') {
                my $messages = $env->{'hippie.message'};
                $messages = [$messages] unless (ref($messages) eq 'ARRAY');
                for my $message(@$messages) {
                    $game->process_message($client_id, $message);
                }
            }
            elsif ($path eq '/error') {
                $game->remove_player($client_id);
            }
            elsif ($path eq '/disconnect') {
                $game->remove_player($client_id);
            }
        }
    };
    mount '/' => sub {
        my $env = shift;

        if (exists $static_files{ $env->{PATH_INFO} }) {
            my $fn = $static_files{ $env->{PATH_INFO} } ? $static_files{ $env->{PATH_INFO} }->{fn} : './' . $env->{PATH_INFO};

            if (-e $fn) {
                my $headers = $static_files{ $env->{PATH_INFO} } ? $static_files{ $env->{PATH_INFO} }->{headers} : [];
                open my $fh, '<' . $fn;
                return [200, $headers, $fh];
            }
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

