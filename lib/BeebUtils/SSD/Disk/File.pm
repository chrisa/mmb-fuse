package BeebUtils::SSD::Disk::File;
use Moo;
use Try::Tiny;

use BeebUtils;

use Errno qw(:POSIX);         # ENOENT EISDIR etc
use Fcntl qw(:DEFAULT :mode); # S_IFREG S_IFDIR, O_SYNC O_LARGEFILE etc.

has 'name' => (is => 'ro', required => 1);
has 'size' => (is => 'ro', required => 1);
has 'data' => (is => 'rw', required => 1);
has 'ssd' => (is => 'ro', required => 1);
has 'dirty' => (is => 'rw', required => 0, default => sub { 0 });

sub getattr {
    my ($self) = @_;
    return (0, 0, S_IFREG | 0644, 1, $<, $(, 0, $self->size, 0, 0, 0, 1, 200);
}

sub truncate {
    my ($self, $offset) = @_;
    $self->dirty(1);
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

    if ($self->ssd->image->free_space < $length) {
        return -ENOSPC();
    }

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
        try {
            my $data = $self->ssd->image->data;
            BeebUtils::add_filedata_to_ssd(\$data, $self->name, $self->data);
            $self->ssd->image->data($data);
            $self->ssd->image->dirty(1);
            $self->ssd->image->release;
            $self->ssd->read_files;
            $self->dirty(0);
        }
        catch {
            warn "caught: $_";
        };
        if ($self->dirty) {
            $self->dirty(0);
            return -ENOSPC();
        }
    }
}

sub unlink {
    my ($self) = @_;

    my $data = $self->ssd->image->data;
    BeebUtils::delete_file(1, $self->name, \$data);
    $self->ssd->image->data($data);
    $self->ssd->image->dirty(1);
    $self->ssd->image->release;
    $self->ssd->read_files;
    $self->dirty(0);
    return;
}

__PACKAGE__->meta->make_immutable;
