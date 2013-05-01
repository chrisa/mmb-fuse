#!/usr/bin/env perl

use strict;
use warnings;

use inc::Module::Install 0.91;

name 'BeebUtils-Fuse';
all_from 'lib/BeebUtils/Fuse.pm';

requires 'Fuse';
requires 'Moo';

author_requires 'Test::NoTabs';
author_requires 'Test::Pod' => '1.14';
author_requires 'Test::Pod::Coverage' => '1.04';
author_tests 't/author';

WriteAll;

