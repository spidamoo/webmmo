package Game::Spacecraft::Station;
use strict;
use warnings;

use parent 'Game::Spacecraft';

sub new {
    my ($class, $params) = @_;

    my $self = $class->SUPER::new($params);

    $self->{schemas} = [{result => {type => 'weapon', codename => 'kinetic_gun', number => 1}, materials => [{codename => 'iron', number => 10}]}];

    return $self;
}

sub msg_schemas {
    my ($self) = @_;
    return {
        type => 'schemas',
        schemas => $self->{schemas},
    };
}


1;
