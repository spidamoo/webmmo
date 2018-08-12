package Game::Effect;
use strict;
use warnings;

sub new {
    my ($class, $params) = @_;

    my $self = bless $params, $class;
    $self->init();

    return $self;
}

sub init {
    my ($self) = @_;

    for ($self->{codename}) {
        if ($_ eq 'shot') {
            $self->{speed} = 400;
            $self->{dx} = $self->{speed} * cos($self->{a});
            $self->{dy} = $self->{speed} * sin($self->{a});
            $self->{ttl} = 1;
        }
    }
}

sub update() {
    my ($self, $dt) = @_;

    for (qw(x y dx dy)) {
        $self->{$_} //= 0;
    }

    $self->{x} += $self->{dx} * $dt;
    $self->{y} += $self->{dy} * $dt;

    if (defined $self->{da}) {
        $self->{a} = 0 unless defined $self->{a};
        $self->{a} += $self->{da} * $dt;
    }

    if (defined $self->{ttl}) {
        $self->{ttl} -= $dt;
        if ($self->{ttl} < 0) {
            $self->{game}->remove_effect($self);
        }
    }
}

sub msg_contents {
    my ($self) = @_;
    return {
        ( map { $_ => $self->{$_} } qw(x y dx dy a da codename) )
    };
}

sub msg {
    return {
        type    => 'effects',
        effects => { $_[0]->{id} => $_[0]->msg_contents() },
    }
}


1;
