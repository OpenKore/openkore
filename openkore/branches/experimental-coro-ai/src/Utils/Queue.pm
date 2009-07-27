package Utils::Queue;

use strict;
use warnings;

use Scalar::Util;

use Log qw(error debug message warning);
use Translation qw(T TF);

# Predeclarations for internal functions
my ($validate_count, $validate_index);

# Create a new queue possibly pre-populated with items
sub new {
    my $class = shift;
    my @queue = map { $_ } @_;
    return bless(\@queue, $class);
}

# Add items to the tail of a queue
sub enqueue {
    my $queue = shift;
    push(@$queue, map { $_ } @_);
}

# Return a count of the number of items on a queue
sub pending {
    my $queue = shift;
    return scalar(@$queue);
}

# Return 1 or more items from the head of a queue, blocking if needed
sub dequeue {
    my $queue = shift;

    my $count = @_ ? $validate_count->(shift) : 1;

    # Return single item
    return shift(@$queue) if ($count == 1);

    # Return multiple items
    my @items;
    push(@items, shift(@$queue)) for (1..$count);
    return @items;
}

# Return items from the head of a queue with no blocking
sub dequeue_nb {
    my $queue = shift;

    my $count = @_ ? $validate_count->(shift) : 1;

    # Return single item
    return shift(@$queue) if ($count == 1);

    # Return multiple items
    my @items;
    for (1..$count) {
        last if (! @$queue);
        push(@items, shift(@$queue));
    }
    return @items;
}

# Return an item without removing it from a queue
sub peek {
    my $queue = shift;
    my $index = @_ ? $validate_index->(shift) : 0;
    return $$queue[$index];
}

# Insert items anywhere into a queue
sub insert {
    my $queue = shift;
    my $index = $validate_index->(shift);
    return if (! @_);   # Nothing to insert

    # Support negative indices
    if ($index < 0) {
        $index += @$queue;
        if ($index < 0) {
            $index = 0;
        }
    }

    # Dequeue items from $index onward
    my @tmp;
    while (@$queue > $index) {
        unshift(@tmp, pop(@$queue))
    }

    # Add new items to the queue
    push(@$queue, map { shared_clone($_) } @_);

    # Add previous items back onto the queue
    push(@$queue, @tmp);
}

# Remove items from anywhere in a queue
sub extract {
    my $queue = shift;

    my $index = @_ ? $validate_index->(shift) : 0;
    my $count = @_ ? $validate_count->(shift) : 1;

    # Support negative indices
    if ($index < 0) {
        $index += @$queue;
        if ($index < 0) {
            $count += $index;
            return if ($count <= 0);            # Beyond the head of the queue
            return $queue->dequeue_nb($count);  # Extract from the head
        }
    }

    # Dequeue items from $index+$count onward
    my @tmp;
    while (@$queue > ($index+$count)) {
        unshift(@tmp, pop(@$queue))
    }

    # Extract desired items
    my @items;
    unshift(@items, pop(@$queue)) while (@$queue > $index);

    # Add back any removed items
    push(@$queue, @tmp);

    # Return single item
    return $items[0] if ($count == 1);

    # Return multiple items
    return @items;
}

### Internal Functions ###

# Check value of the requested index
$validate_index = sub {
    my $index = shift;

    if (! defined($index) ||
        ! looks_like_number($index) ||
        (int($index) != $index))
    {
        my ($method) = (caller(1))[3];
        $method =~ s/Thread::Queue:://;
        $index = 'undef' if (! defined($index));
        error T("Invalid 'index' argument (%s) to '%s' method\n", $index, $method), "system";
    }

    return $index;
};

# Check value of the requested count
$validate_count = sub {
    my $count = shift;

    if (! defined($count) ||
        ! looks_like_number($count) ||
        (int($count) != $count) ||
        ($count < 1))
    {
        my ($method) = (caller(1))[3];
        $method =~ s/Thread::Queue:://;
        $count = 'undef' if (! defined($count));
        error T("Invalid 'count' argument (%s) to '%s' method\n", $count, $method), "system";
    }

    return $count;
};

1;
