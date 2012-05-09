package BeebUtils::SSD::Image;
use Moose;

use BeebUtils;

use Fcntl qw(:DEFAULT :mode); # S_IFREG S_IFDIR, O_SYNC O_LARGEFILE etc.

has 'name' => (is => 'ro', isa => 'Str', required => 1);
has 'image' => (is => 'ro', isa => 'Str', required => 1);

sub getattr {
    return (0, 0, S_IFREG | 0644, 1, $<, $(, 0, 204800, 0, 0, 0, 1, 200);
}

sub read {
    my ($self) = @_;
    return $self->image;
}

1;
