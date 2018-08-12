package Game::Item;
use strict;
use warnings;

use constant {
    EQUIPABLE_TYPES => {
        weapon => 1,
    },
    SKILLS_GIVEN => {
        kinetic_gun => {codename => 'shoot'},
    },
};

sub new {
    my ($class, $params) = @_;

    return $params if ref($params) eq $class;

    my $self = bless {%$params}, $class;
    return $self;
}

sub msg_contents { {codename => $_[0]->{codename}, number => $_[0]->{number},} }

sub craft {
    my ($schema, $ship) = @_;

    for my $material(@{ $schema->{materials} }) {
        return undef unless $ship->has_enough($material);
    }
    for my $material(@{ $schema->{materials} }) {
        $ship->remove_item($material);
    }

    return Game::Item->new($schema->{result});
}

sub given_skill {
    my ($self) = @_;

    return SKILLS_GIVEN->{ $self->{codename} };
}

1;