#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Test::Pod::Coverage 1.04;

# excluding BeebUtils from coverage check.

my $podt = { also_private => [ qr/(^mmb_|^[A-Z_]+$)/ ], };

pod_coverage_ok('BeebUtils::Fuse', $podt);
pod_coverage_ok('BeebUtils::MMB', $podt);
pod_coverage_ok('BeebUtils::SSD::Disk', $podt);
pod_coverage_ok('BeebUtils::SSD::Disk::File', $podt);
pod_coverage_ok('BeebUtils::SSD::Image', $podt);
