package BeebUtils::SSD::Disk::File;
use Moose;

use BeebUtils;

use Fcntl qw(:DEFAULT :mode); # S_IFREG S_IFDIR, O_SYNC O_LARGEFILE etc.

has 'name' => (is => 'ro', isa => 'Str', required => 1);
has 'size' => (is => 'ro', isa => 'Int', required => 1);
has 'data' => (is => 'ro', isa => 'Str', required => 1);

sub getattr {
    my ($self) = @_;
    return (0, 0, S_IFREG | 0644, 1, $<, $(, 0, $self->size, 0, 0, 0, 1, 200);
}

sub read {
    my ($self) = @_;
    return $self->data;
}

1;
