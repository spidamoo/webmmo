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

# TODO: move to the tools pm?
use constant DEBUG => $ENV{DEBUG} // $ENV{PLACK_ENV} eq 'development';

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
);

my %html = (
    'js/Control._.js'   => 'js/Control.js',
    'index._.html'      => 'index.html',
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
            my $client_id = $env->{'hippie.client_id'}; # client id
            my $handle    = $env->{'hippie.handle'};
            my $path      = $env->{PATH_INFO};

            # say "$path $client_id";

            if ($path eq '/init') {
                $game->add_player($client_id, $handle);
            }
            elsif ($path eq '/message') {
                my $messages = $env->{'hippie.message'};
                $messages = [$messages] unless (ref($messages) eq 'ARRAY');
                for my $message(@$messages) {
                    # print STDERR Dumper($message) if DEBUG;
                    $game->process_message($client_id, $message);
                }
            }
            elsif ($path eq '/error') {
                $game->remove_player($client_id);
            }
            elsif ($path eq '/disconnect') {
                $game->remove_player($client_id);
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

