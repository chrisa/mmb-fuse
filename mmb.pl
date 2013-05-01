#!/usr/bin/env perl
use strict;
use warnings;

use lib 'lib';
use BeebUtils::Fuse;

unless (scalar @ARGV == 1) {
    print STDERR "usage: $0 <path to MMB file>\n";
    exit 1;
}
my $mmbfile = $ARGV[0];

my $mountpoint = '/Volumes/mmb';
mkdir $mountpoint;

my $fuse = BeebUtils::Fuse->new(
    mmbfile => $mmbfile,
    mountpoint => $mountpoint
);

$fuse->run;
