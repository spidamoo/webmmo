package Game::Spacecraft::Ship;
use strict;
use warnings;

use parent 'Game::Spacecraft';

use List::Util qw(min);

sub new {
    my ($class, $params) = @_;

    my $self = $class->SUPER::new($params);

    $self->{type} = 'ship';
    $self->{inventory}  = [Game::Item->new({type => 'resource', codename => 'iron', number => 100})];
    $self->{equip} = [
        {type => 'weapon'},
    ];
    $self->{skills}     = [];
    $self->{speed}      = 100;
    $self->{hp}         = 10;
    $self->{max_hp}     = 10;

    return $self;
}

sub dock {
    my ($self, $station) = @_;
    print STDERR "docked\n";
    $self->{docked} = $station;

    $self->update_control();
}
sub undock {
    my ($self) = @_;
    print STDERR "undocked\n";
    $self->{docked} = undef;

    $self->update_control();
}

sub msg_contents {
    my ($self) = @_;
    my $msg = $self->SUPER::msg_contents();
    return {
        %$msg,
        docked => $self->{docked} ? 1 : 0,
        hp     => $self->{hp},
        max_hp => $self->{max_hp},
    }
}

sub msg_inventory {
    return {
        type  => 'inventory',
        items => [map {$_ ? $_->msg_contents() : undef} @{ $_[0]->{inventory} }],
    }
}
sub msg_equip {
    return {
        type  => 'equip',
        slots => [map { { type => $_->{type}, equipped => ($_->{equipped} ? $_->{equipped}->msg_contents() : undef)} } @{ $_[0]->{equip} }],
    }
}
sub msg_skills {
    return {
        type   => 'skills',
        skills => $_[0]->{skills},
    }
}

sub has_enough {
    my ($self, $material)  = @_;
    my $have = 0;

    for my $item(@{ $self->{inventory} }) {
        next unless $item->{codename} eq $material->{codename};
        $have += $item->{number};
    }

    return $have >= $material->{number};
}

sub remove_item {
    my ($self, $material) = @_;
    my $to_remove = $material->{number};

    for my $i(0 .. $#{ $self->{inventory} }) {
        my $item = $self->{inventory}[$i];
        next unless $item && $item->{codename} eq $material->{codename};
        my $remove = min($item->{number}, $to_remove);
        $item->{number} -= $remove;
        $to_remove      -= $remove;
        
        if ($item->{number} <= 0) {
            $self->{inventory}[$i] = undef;
        }

        last if $to_remove <= 0;
    }
}

sub add_item {
    my ($self, $to_add) = @_;
    my $slot;

    for my $i(0 .. $#{ $self->{inventory} }) {
        my $item = $self->{inventory}[$i];
        if (!$item || $item->{codename} eq $to_add->{codename}) {
            $slot = $i;
            last;
        }
    }

    if ($slot) {
        my $item = $self->{inventory}[$slot];
        if ($item) {
            $item->{number} += $to_add->{number};
        }
        else {
            $self->{inventory}[$slot] = Game::Item->new($to_add);
        }
    }
    else {
        push @{ $self->{inventory} }, Game::Item->new($to_add);
    }
}

sub equip {
    my ($self, $what) = @_;

    my $item = $self->{inventory}[$what];
    return unless $item && Game::Item::EQUIPABLE_TYPES->{ $item->{type} };

    my $selected_slot;
    for my $slot(@{ $self->{equip} }) {
        next unless $slot->{type} eq $item->{type};

        $selected_slot = $slot if !$selected_slot || !$slot->{equipped};
        last if !$selected_slot->{equipped};
    }

    return unless $selected_slot;

    $selected_slot->{equipped} = $item;
    $self->{inventory}[$what] = undef;

    $self->update_skills();
}
sub unequip {
    my ($self, $what) = @_;

    my $slot = $self->{equip}[$what];
    return unless $slot && $slot->{equipped};

    $self->add_item($slot->{equipped});
    $slot->{equipped} = undef;

    $self->update_skills();
}

sub update_skills {
    my ($self) = @_;

    $self->{skills} = [];
    for my $i(0 .. $#{ $self->{equip} }) {
        my $slot = $self->{equip}[$i];
        next unless $slot->{equipped};

        my $skill = $slot->{equipped}->given_skill();
        next unless $skill;

        $self->{skills}[$i] = $skill;
    }
}

sub use_skill {
    my ($self, $which, $params) = @_;

    my $skill = $self->{skills}[$which];
    return unless $skill;

    for ($skill->{codename}) {
        if ($_ eq 'shoot') {
            $self->{game}->add_effect( Game::Effect->new({
                codename => 'shot',
                x        => $self->{x},
                y        => $self->{y},
                a        => $params->{a},
                owner_id => $self->{id},
            }),
                zone     => $self->{zone} 
            );
        }
    }
}


sub damage {
    my ($self, $amount) = @_;
    $self->{hp} -= $amount;
    if ($self->{hp} <= 0) {
        $self->die();
    }

    $self->{game}->on_ship_control_update($self);
}

sub die {
    my ($self) = @_;
    $self->{dead} = 1;
}


1;
