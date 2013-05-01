package BeebUtils::Fuse;
use Moo;

require 5.008_001;

our $VERSION = '0.01';
$VERSION = eval $VERSION;

use Fuse;
use Errno qw(:POSIX);         # ENOENT EISDIR etc
use Fcntl qw(:DEFAULT :mode); # S_IFREG S_IFDIR, O_SYNC O_LARGEFILE etc.

use BeebUtils::MMB;
use BeebUtils::SSD::Image;
use BeebUtils::SSD::Disk;
use BeebUtils::SSD::Disk::File;

=pod

=head1 NAME

BeebUtils::Fuse - Fuse wrapper over "BeebUtils"

=head1 SYNOPSIS

  use BeebUtils::Fuse;

  my $fuse = BeebUtils::Fuse->new( mmbfile => $mmbfile, mountpoint => $mountpoint );
  $fuse->run;

=head1 CONSTRUCTOR

=over

=item mountpoint

Filesystem directory to mount the MMB filesystem on.

=item mmb

Path to the MMB file to be mounted.

=item debug

Set to a true value to enable Fuse debugging.

=back

=cut

has 'mountpoint' => (is => 'ro', required => 1);
has 'mmb' => (is => 'ro', required => 1);
has 'debug' => (is => 'ro', required => 0, default => sub { 0 });

has 'fh' => (is => 'rw', required => 1, default => sub { 1 });
has 'openfiles' => (is => 'ro', required => 1, default => sub { {} });

=head1 METHODS

=over

=item run

Start the Fuse implementation.

=cut

sub run {
    my ($self) = @_;
    
    Fuse::main(
        mountpoint => $self->mountpoint,
        debug => $self->debug,
        utimens => sub { $self->mmb_utimens(@_) },
        chown => sub { $self->mmb_chown(@_) },
        chmod => sub { $self->mmb_chmod(@_) },
        getxattr => sub { $self->mmb_getxattr(@_) },
        setxattr => sub { $self->mmb_setxattr(@_) },
        truncate => sub { $self->mmb_truncate(@_) },
        getattr => sub { $self->mmb_getattr(@_) },
        open => sub { $self->mmb_open(@_) },
        mknod => sub { $self->mmb_mknod(@_) },
        read => sub { $self->mmb_read(@_) },
        write => sub { $self->mmb_write(@_) },
        statfs => sub { $self->mmb_statfs(@_) },
        fsync => sub { $self->mmb_fsync(@_) },
        flush => sub { $self->mmb_flush(@_) },
        opendir => sub { $self->mmb_opendir(@_) },
        readdir => sub { $self->mmb_readdir(@_) },
        release => sub { $self->mmb_release(@_) },
        releasedir => sub { $self->mmb_releasedir(@_) },
        unlink => sub { $self->mmb_unlink(@_) },
    );
}

=item next_fh

=cut

sub next_fh {
    my ($self) = @_;
    my $fh = $self->fh + 1;
    $self->fh($fh);
    return $fh;
}

sub BUILDARGS {
    my ($class, %args) = @_;
    my $mmb = BeebUtils::MMB->new( mmbfile => $args{mmbfile} );
    return { mmb => $mmb, mountpoint => $args{mountpoint} };
}

sub mmb_utimens {
    return 0;
}

sub mmb_chown {
    return 0;
}

sub mmb_chmod {
    return 0;
}

sub mmb_getxattr {
    return 0;
}

sub mmb_setxattr {
    return -EOPNOTSUPP();
}

sub mmb_truncate {
    my ($self, $filename, $offset) = @_;
    
    my $entry = $self->mmb->from_path($filename);
    if (defined $entry) {
        $entry->truncate($offset);
    }

    return 0;
}

sub mmb_getattr {
    my ($self, $filename) = @_;

    if ($filename eq '/') {
        # root
        return (0, 0, S_IFDIR | 0755, 1, $<, $(, 0, 2, 0, 0, 0, 1, 200);
    }
    else {
        my $entry = $self->mmb->from_path($filename);
        if (defined $entry) {
            return $entry->getattr;
        }
        else {
            return -ENOENT();
        }
    }
}

sub mmb_statfs {
    my ($self) = @_;
    return $self->mmb->statfs;
}

sub mmb_access {
    return 0;
}

sub mmb_open {
    my ($self, $pathname, $flags, $fileinfo) = @_;
    
    my $entry = $self->mmb->from_path($pathname);
    if (defined $entry) {
        my $error = $entry->open($flags);
        $self->openfiles->{$self->next_fh} = $entry;
        return ($error, $self->fh);
    }
    return -ENOENT();
}

sub mmb_mknod {
    my ($self, $pathname, $modes, $device) = @_;
    return $self->mmb->mknod($pathname, $modes, $device);
}

sub mmb_read {
    my ($self, $pathname, $size, $offset, $fh) = @_;

    my $entry = $self->openfiles->{$fh};
    if (defined $entry) {
        my $data = $entry->read;
        return substr $data, $offset, $size;
    }
    return -EBADF();
}

sub mmb_write {
    my ($self, $pathname, $data, $offset, $fh) = @_;

    my $entry = $self->openfiles->{$fh};
    if (defined $entry) {
        return $entry->write($data, $offset);
    }
    
    return -EBADF();
}

sub mmb_flush {
    return 0;
}

sub mmb_release {
    my ($self, $pathname, $flags, $fh) = @_;

    my $entry = $self->openfiles->{$fh};
    my $error = 0;
    if (defined $entry) {
        $error = $entry->release;
    }
    delete $self->openfiles->{$fh};
    return $error;
}

sub mmb_opendir {
    return 0;
}

sub mmb_readdir {
    my ($self, $dirname, $offset) = @_;
    my @entries;

    if ($dirname eq '/') {
        @entries = ('disks', 'images');
    }
    else {
        my $entry = $self->mmb->from_path($dirname);
        unless (defined $entry) {
            return -ENOENT();
        }
        @entries = $entry->readdir;
    }

    push @entries, 0;
    splice @entries, 0, $offset;
    return @entries;
}

sub mmb_releasedir {
    return 0;
}

sub mmb_unlink {
    my ($self, $pathname) = @_;

    my $entry = $self->mmb->from_path($pathname);
    unless (defined $entry) {
        return -ENOENT();
    }

    $entry->unlink;
    return 0;
}

=back

=cut

__PACKAGE__->meta->make_immutable;

__END__

=head1 AUTHOR

Stephen Harris
Chris Andrews <chris@nodnol.og>

=head1 COPYRIGHT

lib/BeebUtils.pm is (C) 2012 Stephen Harris, and is licenced under the
GPL.

Other files here are (C) 2012-2013 Chris Andrews and are also licenced
under the GPL.

=head1 LICENCE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut
