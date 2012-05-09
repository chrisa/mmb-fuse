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

Fuse::main(
    mountpoint => $mountpoint,
    debug => 1,
    getattr => 'main::mmb_getattr',
    open => 'main::mmb_open',
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
    return (0);
}

sub mmb_open {
    return (0);
}

sub mmb_read {
    my ($pathname, $size, $offset) = @_;
    
    my $entry = $mmb->from_path($pathname);
    my $data = $entry->read;
    return substr $data, $offset, $size;
}

sub mmb_write {
    my ($pathname, $data, $size, $fh) = @_;
        
}

sub mmb_flush {
    return (0);
}

sub mmb_release {
    return (0);
}

sub mmb_opendir {
    my ($dirname) = @_;
    return (0);
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
    return (0);
}

