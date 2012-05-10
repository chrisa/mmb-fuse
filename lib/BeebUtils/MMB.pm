package BeebUtils::MMB;
use Moose;

use BeebUtils;
use BeebUtils::SSD::Image;
use BeebUtils::SSD::Disk;

use Errno qw(:POSIX);         # ENOENT EISDIR etc
use Fcntl qw(:DEFAULT :mode); # S_IFREG S_IFDIR, O_SYNC O_LARGEFILE etc.

has 'mmbfile' => (is => 'ro', isa => 'Str', required => 1);
has 'dtable' => (is => 'rw', isa => 'Str', required => 0);
has 'dcat' => (is => 'rw', isa => 'HashRef', required => 0);

sub BUILD {
    my ($self) = @_;

    BeebUtils::init($self->mmbfile);
    $self->dtable(BeebUtils::LoadDiskTable());
    $self->dcat({ BeebUtils::load_dcat(\$self->dtable) });
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
    for my $dr (keys %{ $self->dcat }) {
        if ($name eq $self->dcat->{$dr}->{DiskTitle}) {
            $index = $dr;
            last;
        }
    }

    if (defined $index) {
        my $image = BeebUtils::read_ssd($index);
        return BeebUtils::SSD::Image->new(
            name => $name,
            image => $image,
            index => $index,
        );
    }

    return;
}

sub disk_ssd {
    my ($self, $name) = @_;

    my $index;
    for my $dr (keys %{ $self->dcat }) {
        if ($name eq $self->dcat->{$dr}->{DiskTitle}) {
            $index = $dr;
            last;
        }
    }
    my $image = BeebUtils::read_ssd($index);

    return BeebUtils::SSD::Disk->new( name => $name, image => $image );
}

sub getattr {
    my ($self) = @_;
    
    my @entries = (map { $self->dcat->{$_}->{DiskTitle} . '.ssd' } 
                  grep { $self->dcat->{$_}->{Formatted} }
            sort keys %{ $self->dcat } );

    return (0, 0, S_IFDIR | 0755, 1, $<, $(, 0, (scalar @entries), 0, 0, 0, 1, 200);
}

sub statfs {
    my ($self) = @_;

    my $disks = scalar keys %{ $self->dcat };
    return (8, $disks, 0, 200 * $disks, 0, 1);
}

sub readdir {
    my ($self) = @_;

    my @entries = (map { $self->dcat->{$_}->{DiskTitle} . '.ssd' } 
                  grep { $self->dcat->{$_}->{Formatted} }
            sort keys %{ $self->dcat } );
    
    return @entries;
}

sub mknod {
    my ($self, $pathname, $modes, $device) = @_;
    
    if ($pathname =~ m!^/images/(.+)\.ssd$!) {
        my $ssd = $1;

        my $index;
        for (my $i = 0; $index < 255; $index++) {
            if (!exists $self->dcat->{$i} || $self->dcat->{$i}->{Formatted} == 0) {
                $index = $i;
                last;
            }
        }
        if (defined $index) {
            my $dtable = $self->dtable;
            BeebUtils::DeleteSlot($index, 1, \$dtable);
            BeebUtils::ChangeDiskName($index, $ssd, \$dtable);
            BeebUtils::SaveDiskTable(\$dtable);
            $self->dtable($dtable);
            $self->dcat({ BeebUtils::load_dcat(\$self->dtable) });
            return (0);
        }
        else {
            return -ENOSPC;
        }
    }
    else {
        return -EROFS;
    }
}

1;
