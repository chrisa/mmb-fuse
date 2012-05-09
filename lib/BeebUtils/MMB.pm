package BeebUtils::MMB;
use Moose;

use BeebUtils;
use BeebUtils::SSD::Image;
use BeebUtils::SSD::Disk;

use Fcntl qw(:DEFAULT :mode); # S_IFREG S_IFDIR, O_SYNC O_LARGEFILE etc.

has 'mmbfile' => (is => 'ro', isa => 'Str', required => 1);
has 'disk' => (is => 'rw', isa => 'HashRef', required => 0);

sub BUILD {
    my ($self) = @_;

    BeebUtils::init($self->mmbfile);
    $self->disk({ BeebUtils::load_dcat() });
}

sub from_path {
    my ($self, $path) = @_;
    
    my $entry;

    if ($path =~ m!^/images/(.+)\.ssd$!) {
        my $ssd = $1;
        $entry = $self->image_ssd($ssd);
    }
    elsif ($path eq '/disks' || $path eq '/images') {
        $entry = $self;
    }
    elsif ($path =~ m!^/disks/(.+)\.ssd$!) {
        my $ssd = $1;
        $entry = $self->disk_ssd($ssd);
    }
    elsif ($path =~ m!^/disks/(.+).ssd/(.+)$!) {
        my $ssd = $1;
        my $file = $2;
        $entry = $self->disk_ssd($ssd)->file($file);
    }
    else {
        #die "no entry for $path";
    }

    return $entry;
}

sub image_ssd {
    my ($self, $name) = @_;

    my $index;
    for my $dr (keys %{ $self->disk }) {
        if ($name eq $self->disk->{$dr}->{DiskTitle}) {
            $index = $dr;
            last;
        }
    }
    my $image = BeebUtils::read_ssd($index);
    
    return BeebUtils::SSD::Image->new( name => $name, image => $image );
}

sub disk_ssd {
    my ($self, $name) = @_;

    my $index;
    for my $dr (keys %{ $self->disk }) {
        if ($name eq $self->disk->{$dr}->{DiskTitle}) {
            $index = $dr;
            last;
        }
    }
    my $image = BeebUtils::read_ssd($index);

    return BeebUtils::SSD::Disk->new( name => $name, image => $image );
}

sub getattr {
    my ($self) = @_;
    
    my @entries = (map { $self->disk->{$_}->{DiskTitle} . '.ssd' } 
                  grep { $self->disk->{$_}->{Formatted} }
            sort keys %{ $self->disk } );

    return (0, 0, S_IFDIR | 0755, 1, $<, $(, 0, (scalar @entries), 0, 0, 0, 1, 200);
}

sub statfs {
    my ($self) = @_;

    my $disks = scalar keys %{ $self->disk };
    return (8, $disks, 0, 200 * $disks, 0, 1);
}

sub readdir {
    my ($self) = @_;

    my @entries = (map { $self->disk->{$_}->{DiskTitle} . '.ssd' } 
                  grep { $self->disk->{$_}->{Formatted} }
            sort keys %{ $self->disk } );
    
    return @entries;
}

1;
