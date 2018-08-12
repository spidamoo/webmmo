package Game::Player;
use strict;
use warnings;

sub new {
    my ($class, $params) = @_;

    return bless $params, $class;
}

sub send_msg {
    my ($self, $msg) = @_;
    $self->{handle}->send_msg($msg);
}

1;
