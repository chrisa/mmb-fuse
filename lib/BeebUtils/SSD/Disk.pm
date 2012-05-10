package BeebUtils::SSD::Disk;
use Moose;
use Try::Tiny;

use BeebUtils;
use BeebUtils::SSD::Disk::File;

use Fcntl qw(:DEFAULT :mode); # S_IFREG S_IFDIR, O_SYNC O_LARGEFILE etc.

has 'name' => (is => 'ro', isa => 'Str', required => 1);
has 'image' => (is => 'ro', isa => 'Object', required => 1);
has 'files' => (is => 'rw', isa => 'HashRef', required => 0);

sub BUILD {
    my ($self) = @_;

    my %files = BeebUtils::read_cat(\$self->image->image);
    
    for my $index (keys %files) {
        next if $index eq '';
        $files{$index}->{unix_name} = $files{$index}->{name};
        $files{$index}->{unix_name} =~ s!/!_!g;
    }
    $self->files(\%files);
}

sub getattr {
    my ($self) = @_;

    return (0, 0, S_IFDIR | 0755, 1, $<, $(, 0, (scalar keys %{ $self->files }), 0, 0, 0, 1, 200);
}

sub readdir {
    my ($self) = @_;

    my @entries = map { $self->files->{$_}->{unix_name} } sort keys %{ $self->files };
    return @entries;
}

sub file {
    my ($self, $name) = @_;

    my $file;
    for my $f (keys %{ $self->files }) {
        next unless exists $self->files->{$f}->{unix_name};
        if ($self->files->{$f}->{unix_name} eq $name) {
            $file = $self->files->{$f};
            last;
        }
    }
    
    return unless $file;

    my $data;
    try {
        $data = BeebUtils::ExtractFile(\$self->image->image, $file->{name}, %{ $self->files });
    };
    if (defined $data) {
        return BeebUtils::SSD::Disk::File->new(
            name => $file->{unix_name},
            size => $file->{size},
            data => $data,
            ssd => $self,
        );
    }

    return;
}

sub mknod {
    my ($self, $file) = @_;

    my $index = $self->files->{''}->{filecount};
    if ($index > 31) {
        return -ENOSPC;
    }
    $self->files->{''}->{filecount}++;

    $self->files->{$index} = {
        cat_sector => 0,
        unix_name => $file,
        name => $file,
        locked => 0,
        load => 0,
        exec => 0,
        size => 0,
        start => 0, # not correct, but this isn't assigned yet
    };

    return 0;
}

1;
