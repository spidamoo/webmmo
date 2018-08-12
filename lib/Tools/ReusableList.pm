package Tools::ReusableList;
use strict;
use warnings;

sub new {
    my ($class, $params) = @_;

    my $self = bless {_array => [], _free_indices => []}, $class;

    return $self;
}

sub add {
    my ($self, $new_item) = @_;

    if (@{ $self->{_free_indices} }) {
        my $index = shift @{ $self->{_free_indices} };
        $self->{_array}[$index] = $new_item;
        return $index;
    }
    else {
        push @{ $self->{_array} }, $new_item;
        return $#{ $self->{_array} };
    }
}

sub remove {
    my ($self, $remove_index) = @_;

    if ( $remove_index == $#{ $self->{_array} } ) {
        pop @{ $self->{_array} };
    }
    else {
        push @{ $self->{_free_indices} }, $remove_index;
        $self->{_array}[$remove_index] = undef;
    }
}

sub aref {
    return $_[0]->{_array};
}

1;
