package BeebUtils::SSD::Image;
use Moo;

use BeebUtils;

use Fcntl qw(:DEFAULT :mode); # S_IFREG S_IFDIR, O_SYNC O_LARGEFILE etc.

has 'name' => (is => 'ro', required => 1);
has 'index' => (is => 'ro', required => 1);
has 'data' => (is => 'rw', required => 1);
has 'dirty' => (is => 'rw', required => 0, default => sub { 0 });

sub getattr {
    my ($self) = @_;
    my $size = $self->space_used;
    return (0, 0, S_IFREG | 0644, 1, $<, $(, 0, $size, 0, 0, 0, 1, 200);
}

sub truncate {
    my ($self, $offset) = @_;
    $self->data('');
}

sub read {
    my ($self) = @_;
    return $self->data;
}

sub open {
    my ($self, $flags) = @_;

    if (($flags & O_RDWR) || ($flags & O_WRONLY)) {
        $self->dirty(1);
        if ($flags & O_TRUNC) {
            $self->truncate(0);
        }
    }

    return 0;
}

sub write {
    my ($self, $data, $offset) = @_;
    my $length = length $data;
    my $image = $self->data;

    if (length $image < ($length + $offset)) {
        $image .= ("\0" x (($length + $offset) - length $image));
    }
    substr $image, $offset, $length, $data;

    $self->data($image);
    
    return $length;
}

sub release {
    my ($self) = @_;

    if ($self->dirty) {
        BeebUtils::put_ssd($self->data, $self->index);
        $self->dirty(0);
    }
    
    return 0;
}

# --------------------------------------------------------------------

sub space_used {
    my ($self) = @_;

    my %files = BeebUtils::read_cat(\$self->data);
    my $size = 0;
    if (exists $files{0}) {
        $size = 256 * $files{0}->{start} + $files{0}->{size};
    }
    return $size;
}

sub size {
    my ($self) = @_;

    my %files = BeebUtils::read_cat(\$self->data);
    my $size = $files{""}{disk_size} * 256;
    return $size;
}

sub free_space {
    my ($self) = @_;
    return $self->size - $self->space_used;
}

__PACKAGE__->meta->make_immutable;
