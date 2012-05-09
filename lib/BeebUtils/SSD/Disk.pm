package BeebUtils::SSD::Disk;
use Moose;
use Try::Tiny;

use BeebUtils;
use BeebUtils::SSD::Disk::File;

use Fcntl qw(:DEFAULT :mode); # S_IFREG S_IFDIR, O_SYNC O_LARGEFILE etc.

has 'name' => (is => 'ro', isa => 'Str', required => 1);
has 'image' => (is => 'ro', isa => 'Str', required => 1);
has 'files' => (is => 'rw', isa => 'HashRef', required => 0);

sub BUILD {
    my ($self) = @_;

    my %files = BeebUtils::read_cat(\$self->image);
    
    for my $index (keys %files) {
        next if $index eq '';
        $files{$index}->{dfs_name} = $files{$index}->{name};
        $files{$index}->{name} =~ s!/!_!g;
    }
    $self->files(\%files);
}

sub getattr {
    my ($self) = @_;

    return (0, 0, S_IFDIR | 0755, 1, $<, $(, 0, (scalar keys %{ $self->files }), 0, 0, 0, 1, 200);
}

sub readdir {
    my ($self) = @_;

    my @entries = map { $self->files->{$_}->{name} } sort keys %{ $self->files };
    return @entries;
}

sub file {
    my ($self, $name) = @_;
    
    my $file;
    for my $f (keys %{ $self->files }) {
        next unless exists $self->files->{$f}->{name};
        if ($self->files->{$f}->{name} eq $name) {
            $file = $self->files->{$f};
            last;
        }
    }

    my $data;
    try {
        $data = BeebUtils::ExtractFile(\$self->image, $file->{dfs_name});
    };
    if (defined $data) {
        return BeebUtils::SSD::Disk::File->new( name => $name, size => $file->{size}, data => $data );
    }

    return;
}

1;
