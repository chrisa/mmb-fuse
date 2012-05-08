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

    if ($filename eq '/') {
        # root
        return (0, 0, S_IFDIR | 0755, 1, $<, $(, 0, (scalar keys %$disk), 0, 0, 0, 1, 200);
    }
    elsif ($filename =~ m!^/images/.+\.ssd$!) {
        # disk image
        return (0, 0, S_IFREG | 0644, 1, $<, $(, 0, 204800, 0, 0, 0, 1, 200);
    }
    elsif ($filename eq '/disks' || $filename eq '/images') {
        my @entries =
             (map { $disk->{$_}->{DiskTitle} . '.ssd' } 
                   grep { $disk->{$_}->{Formatted} }
                        sort keys %$disk
                    );
        return (0, 0, S_IFDIR | 0755, 1, $<, $(, 0, (scalar @entries), 0, 0, 0, 1, 200);
    }
    elsif ($filename =~ m!^/disks/(.+)\.ssd$!) {
        # disk
        my $image = $1;
        my $index = find_ssd_index($image);
        my $files = ssd_info($index);
        return (0, 0, S_IFDIR | 0755, 1, $<, $(, 0, (scalar keys %$files), 0, 0, 0, 1, 200);
    }
    elsif ($filename =~ m!^/disks/(.+).ssd/(.+)$!) {
        # file on disk
        my $image = $1;
        my $file = $2;

        my $index = find_ssd_index($image);
        my $files = ssd_info($index);
        my $size = 0;

        for my $f (keys %$files) {
            next unless exists $files->{$f}->{name};
            if ($files->{$f}->{name} eq $file) {
                $size = $files->{$f}->{size};
                last;
            }
        }
        return (0, 0, S_IFREG | 0644, 1, $<, $(, 0, $size, 0, 0, 0, 1, 200);
    }
    else {
        # nothing
    }
}

sub mmb_getdir {
    my ($dirname) = @_;
    
    if ($dirname eq '/') {
        return ('disks', 'images', 0);
    }
    elsif ($dirname eq '/disks' || $dirname eq '/images') {
        return (map { $_->{DiskTitle} } values %$disk), 0;
    }
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
    
    if ($pathname =~ m!/disks/(.+).ssd/(.+)$!) {
        my $ssd = $1;
        my $filename = $2;

        my $index = find_ssd_index($ssd);
        my $image = ssd_image($index);

        my $data = BeebUtils::ExtractFile(\$image, $filename);
        
        return substr $data, $offset, $size;
    }
    elsif ($pathname =~ m!/images/(.+).ssd$!) {
        my $ssd = $1;

        my $index = find_ssd_index($ssd);
        my $image = ssd_image($index);
        
        return substr $image, $offset, $size;
    }
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
    elsif ($dirname eq '/disks' || $dirname eq '/images') {
        @entries =
             (map { $disk->{$_}->{DiskTitle} . '.ssd' } 
                   grep { $disk->{$_}->{Formatted} }
                        sort keys %$disk
                    );
    }
    elsif ($dirname =~ m!/disks/(.+).ssd$!) {
        my $ssd = $1;
        my $index = find_ssd_index($ssd);
        my $files = ssd_info($index);
        @entries = map { $files->{$_}->{name} } sort keys %$files;
    }
    push @entries, 0;
    splice @entries, 0, $offset;
    return @entries;
}

sub mmb_releasedir {
    return (0);
}

# ----------------------------------------------------------------------

sub find_ssd_index {
    my ($dirname) = @_;
    
    my $index;
    for my $dr (keys %$disk) {
        if ($dirname eq $disk->{$dr}->{DiskTitle}) {
            $index = $dr;
            last;
        }
    }
    
    return $index;
}

sub ssd_info {
    my ($index) = @_;
    
    my $image = ssd_image($index);
    my $files = { BeebUtils::read_cat(\$image) };
    
    return $files;
}

sub ssd_image {
    my ($index) = @_;
    
    my $image = BeebUtils::read_ssd($index);
    
    return $image;
}
