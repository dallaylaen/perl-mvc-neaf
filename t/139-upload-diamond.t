#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Scalar::Util qw(weaken);

use MVC::Neaf::Upload;

my $up = MVC::Neaf::Upload->new( id => "data", handle => \*DATA );

is <$up>, "Foo\n", "Diamond op works";
is <$up>, "Bared\n", "Diamond op works again";

{
    package Vanish;
    sub new {
        my ($class, $str) = @_;
        bless \$str, $class;
    };
    sub str {
        return ${ $_[0] };
    };
};

# Because we use inside-out objects, must also test for leaks
note "TESTING LEAK";
my $leaky = Vanish->new("fname");
my $weak  = [$leaky];
weaken $weak->[0];

my $newup = MVC::Neaf::Upload->new(
    id => "leak", filename => $leaky, handle => \*DATA );

undef $leaky;
is ref $weak->[0], "Vanish", "Leaky ref still present";
is $newup->filename->str, "fname", "Leaky ref in upload obj";
undef $newup;
ok !$weak->[0], "Leaky ref disappeared";

done_testing;

__DATA__
Foo
Bared
Bazzz
