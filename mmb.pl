#!/opt/local/bin/perl
use strict;
use warnings;
use Data::Dumper;

use Fuse;
use Errno qw(:POSIX);         # ENOENT EISDIR etc
use Fcntl qw(:DEFAULT :mode); # S_IFREG S_IFDIR, O_SYNC O_LARGEFILE etc.

use lib 'lib';
use BeebUtils::MMB;

my $mountpoint = '/Volumes/mmb';
mkdir $mountpoint;

my $mmbfile = '/Users/chris/Projects/mmb-fuse/BEEB.MMB';
my $mmb = BeebUtils::MMB->new( mmbfile => $mmbfile );

my $fh = 1;
my $openfiles = {};

Fuse::main(
    mountpoint => $mountpoint,
    debug => 0,
    utimens => 'main::mmb_utimens',
    chown => 'main::mmb_chown',
    chmod => 'main::mmb_chmod',
    setxattr => 'main::mmb_setxattr',
    truncate => 'main::mmb_truncate',
    getattr => 'main::mmb_getattr',
    open => 'main::mmb_open',
    mknod => 'main::mmb_mknod',
    read => 'main::mmb_read',
    write => 'main::mmb_write',
    statfs => 'main::mmb_statfs',
    fsync => 'main::mmb_fsync',
    flush => 'main::mmb_flush',
    opendir => 'main::mmb_opendir',
    readdir => 'main::mmb_readdir',
    release => 'main::mmb_release',
    releasedir => 'main::mmb_releasedir',
);

sub mmb_utimens {
    return 0;
}

sub mmb_chown {
    return 0;
}

sub mmb_chmod {
    return 0;
}

sub mmb_setxattr {
    return 0;
}

sub mmb_truncate {
    my ($filename, $offset) = @_;
    
    my $entry = $mmb->from_path($filename);
    if (defined $entry) {
        $entry->truncate($offset);
    }

    return 0;
}

sub mmb_getattr {
    my ($filename) = @_;

    if ($filename eq '/') {
        # root
        return (0, 0, S_IFDIR | 0755, 1, $<, $(, 0, 2, 0, 0, 0, 1, 200);
    }
    else {
        my $entry = $mmb->from_path($filename);
        if (defined $entry) {
            return $entry->getattr;
        }
        else {
            return -ENOENT();
        }
    }
}

sub mmb_statfs {
    return $mmb->statfs;
}

sub mmb_access {
    return 0;
}

sub mmb_open {
    my ($pathname, $flags, $fileinfo) = @_;
    
    my $entry = $mmb->from_path($pathname);
    if (defined $entry) {
        my $error = $entry->open($flags);
        $openfiles->{++$fh} = $entry;
        return ($error, $fh);
    }
    return -ENOENT();
}

sub mmb_mknod {
    my ($pathname, $modes, $device) = @_;
    return $mmb->mknod($pathname, $modes, $device);
}

sub mmb_read {
    my ($pathname, $size, $offset, $fh) = @_;

    my $entry = $openfiles->{$fh};
    if (defined $entry) {
        my $data = $entry->read;
        return substr $data, $offset, $size;
    }
    return -EBADF();
}

sub mmb_write {
    my ($pathname, $data, $offset, $fh) = @_;

    my $entry = $openfiles->{$fh};
    if (defined $entry) {
        return $entry->write($data, $offset);
    }
    
    return -EBADF();
}

sub mmb_flush {
    return 0;
}

sub mmb_release {
    my ($pathname, $flags, $fh) = @_;

    my $entry = $openfiles->{$fh};
    my $error = 0;
    if (defined $entry) {
        $error = $entry->release;
    }
    delete $openfiles->{$fh};
    return $error;
}

sub mmb_opendir {
    my ($dirname) = @_;
    return 0;
}

sub mmb_readdir {
    my ($dirname, $offset) = @_;
    my @entries;

    if ($dirname eq '/') {
        @entries = ('disks', 'images');
    }
    else {
        my $entry = $mmb->from_path($dirname);
        @entries = $entry->readdir;
    }

    push @entries, 0;
    splice @entries, 0, $offset;
    return @entries;
}

sub mmb_releasedir {
    return 0;
}

