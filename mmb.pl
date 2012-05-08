#!/opt/local/bin/perl
use strict;
use warnings;
use Data::Dumper;

use Fuse;
use Errno qw(:POSIX);         # ENOENT EISDIR etc
use Fcntl qw(:DEFAULT :mode); # S_IFREG S_IFDIR, O_SYNC O_LARGEFILE etc.

use lib '.';
use BeebUtils;

my $mountpoint = '/Volumes/mmb';
mkdir $mountpoint;

my $mmbfile = '/Users/chris/Projects/mmb-fuse/BEEB.MMB';

BeebUtils::init($mmbfile);
my $disk = { BeebUtils::load_dcat() };

Fuse::main(
    mountpoint => $mountpoint,
    debug => 1,
    getattr => 'main::mmb_getattr',
    getdir => 'main::mmb_getdir',
    open => 'main::mmb_open',
    read => 'main::mmb_read',
    write => 'main::mmb_write',
    statfs => 'main::mmb_statfs',
    fsync => 'main::mmb_fsync',
    flush => 'main::mmb_flush',
    opendir => 'main::mmb_opendir',
    readdir => 'main::mmb_readdir',
    #access => 'main::mmb_access',
    release => 'main::mmb_release',
    releasedir => 'main::mmb_releasedir',
);

sub mmb_getattr {
    my ($filename) = @_;
    if ($filename eq '/' || $filename =~ m!/.+\.ssd$!) {
        return (0, 0, S_IFDIR | 0755, 1, $<, $(, 0, 204800, 0, 0, 0, 1, 200);
    }
    else {
        print STDERR "getattr: $filename\n";

        return (0, 0, S_IFREG | 0644, 1, $<, $(, 0, 204800, 0, 0, 0, 1, 200);
    }        
}

sub mmb_getdir {
    my ($dirname) = @_;
    return (map { $_->{DiskTitle} } values %$disk), 0;
}

sub mmb_statfs {
    return (8, scalar keys %$disk, 0, 200 * scalar keys %$disk, 0, 1);
}

sub mmb_access {
    return (0);
}

sub mmb_open {
    return (0);
}

sub mmb_read {
    my ($pathname, $size, $offset) = @_;
    return "";
}

sub mmb_flush {

}

sub mmb_release {

}

sub mmb_opendir {
    my ($dirname) = @_;
    return (0);
}

sub mmb_readdir {
    my ($dirname, $offset) = @_;
    my @entries;

    if ($dirname eq '/') {
        @entries =
             (map { $disk->{$_}->{DiskTitle} . '.ssd' } 
                   grep { $disk->{$_}->{Formatted} }
                        sort keys %$disk
                    );
    }
    else {
        my $ssd;
        for my $dr (keys %$disk) {
            if ($dirname eq '/' . $disk->{$dr}->{DiskTitle} . '.ssd') {
                $ssd = $dr;
                last;
            }
        }
        my $image = BeebUtils::read_ssd($ssd);
        my $files = { BeebUtils::read_cat(\$image) };
        @entries = map { $files->{$_}->{name} } sort keys %$files;
    }
    push @entries, 0;
    splice @entries, 0, $offset;
    return @entries;
}

sub mmb_releasedir {
    return (0);
}
