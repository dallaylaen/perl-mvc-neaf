#!/isr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use Cwd qw(abs_path);

use MVC::Neaf::Util::Dir;

my $testdir = abs_path(dirname(__FILE__));

my $here = MVC::Neaf::Util::Dir->new('.');

is $here->path('.'), $testdir, 'local file detected correctly';
is $here->path('bonk///'), "$testdir/bonk", 'directory appended correctly';
is $here->path('/foo/bar'), '/foo/bar', 'absolute path goes untouched';

my $there = MVC::Neaf::Util::Dir->new('/www/myproject');
is $there->path('.'), '/www/myproject', 'dot does nothing';
is $there->path('..'), '/www/myproject/..', 'parent dir abbreviated';
is $there->path('/etc/passwd'), '/etc/passwd', 'absolute path goes untouched';

done_testing;
