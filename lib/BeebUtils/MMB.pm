package BeebUtils::MMB;
use Moo;

=head1 NAME

BeebUtils::MMB - an MMB file containing many SSD images

=cut

use Errno qw(:POSIX);         # ENOENT EISDIR etc
use Fcntl qw(:DEFAULT :mode); # S_IFREG S_IFDIR, O_SYNC O_LARGEFILE etc.

use BeebUtils;

has 'mmbfile' => (is => 'ro', required => 1);
has 'dtable' => (is => 'rw', required => 0);
has 'dcat' => (is => 'rw', required => 0);

has '_disks' => (is => 'ro', required => 0, default => sub { {} });
has '_images' => (is => 'ro', required => 0, default => sub { {} });

sub BUILD {
    my ($self) = @_;

    BeebUtils::init($self->mmbfile);
    $self->dtable(BeebUtils::LoadDiskTable());
    $self->dcat({ BeebUtils::load_dcat(\$self->dtable) });
}

=head1 METHODS

=over

=item from_path($path)

Returns an instance of the appropriate object corresponding to the
given $path.

This may be:

 directory: /disks/*.ssd   -> BeebUtils::SSD::Disk
      file: /disks/*.ssd/* -> BeebUtils::SSD::Disk::File
      file: /images/*.ssd  -> BeebUtils::SSD::Image

=cut

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
        return;
    }

    return $entry;
}

=item image_ssd($name)

Returns an instance of BeebUtils::SSD::Image corresponding to the
given image file name.

=cut

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
        return BeebUtils::SSD::Image->new(
            data => BeebUtils::read_ssd($index),
            name => $name,
            index => $index,
        );
    }

    return;
}

sub disk_ssd {
    my ($self, $name) = @_;

    if (exists $self->_disks->{$name}) {
       return $self->_disks->{$name};
    }

    my $index;
    for my $dr (keys %{ $self->dcat }) {
        if ($name eq $self->dcat->{$dr}->{DiskTitle}) {
            $index = $dr;
            last;
        }
    }
    return unless defined $index;

    my $image = BeebUtils::SSD::Image->new(
        data => BeebUtils::read_ssd($index),
        name => $name,
        index => $index,
    );

    return BeebUtils::SSD::Disk->new(
        name => $name,
        image => $image
    );
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
        for (my $i = 0; $i < 255; $i++) {
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

            my $image = BeebUtils::SSD::Image->new(
                data => BeebUtils::blank_ssd(),
                name => $ssd,
                index => $index,
            );
            $image->dirty(1);
            $image->release;

            return (0);
        }
        else {
            return -ENOSPC();
        }
    }
    elsif ($pathname =~ m!^/disks/(.+).ssd/(.+)$!) {
        my $ssd = $1;
        my $file = $2;

        unless ($file =~ /^.\..+$/) {
            return -EINVAL();
        }
        
        my $entry = $self->disk_ssd($ssd);
        if (defined $entry) {
            $self->_disks->{$ssd} = $entry;
            return $entry->mknod($file);
        }
        else {
            return -ENOENT();
        }
    }
    else {
        return -EROFS();
    }
}

__PACKAGE__->meta->make_immutable;
