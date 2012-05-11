package BeebUtils::SSD::Disk::File;
use Moose;
use Try::Tiny;

use BeebUtils;

use Errno qw(:POSIX);         # ENOENT EISDIR etc
use Fcntl qw(:DEFAULT :mode); # S_IFREG S_IFDIR, O_SYNC O_LARGEFILE etc.

has 'name' => (is => 'ro', isa => 'Str', required => 1);
has 'size' => (is => 'ro', isa => 'Int', required => 1);
has 'data' => (is => 'rw', isa => 'Str', required => 1);
has 'ssd' => (is => 'ro', isa => 'Object', required => 1);
has 'dirty' => (is => 'rw', isa => 'Bool', required => 0, default => 0);

sub getattr {
    my ($self) = @_;
    return (0, 0, S_IFREG | 0644, 1, $<, $(, 0, $self->size, 0, 0, 0, 1, 200);
}

sub truncate {
    my ($self, $offset) = @_;
    $self->data('');
}

sub open {
    my ($self, $flags) = @_;

    if (($flags & O_RDWR) || ($flags & O_WRONLY)) {
        $self->dirty(1);
        $self->truncate(0);
    }
    
    return 0;
}

sub read {
    my ($self) = @_;
    return $self->data;
}

sub write {
    my ($self, $data, $offset) = @_;
    my $length = length $data;
    my $file = $self->data;

    if (length $file < ($length + $offset)) {
        $file .= ("\0" x (($length + $offset) - length $file));
    }
    substr $file, $offset, $length, $data;

    $self->data($file);
    
    return $length;
}

sub release {
    my ($self) = @_;

    if ($self->dirty) {
        my $image = $self->ssd->image->image;
        try {
            BeebUtils::add_filedata_to_ssd(\$image, $self->name, $self->data);
            $self->ssd->image->image($image);
            $self->ssd->image->dirty(1);
            $self->ssd->image->release;
            $self->ssd->BUILD;
            $self->dirty(0);
        };
        if ($self->dirty) {
            $self->dirty(0);
            return -ENOSPC();
        }
    }
}

1;
