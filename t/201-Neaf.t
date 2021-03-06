#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf;

# Test view loading by alias
neaf->load_view( foo => TT => EVAL_PERL => 1 );
my $v = neaf->get_view("foo");
is (ref $v, "MVC::Neaf::View::TT", "Good view created");
is_deeply ([$v->render({ -template => \'[% PERL %]print 42;[% END %]' })],
    [42, "text/html"], "Template args round trip");

# first, prepare some test subs
neaf->route( foo => sub {
    my $req = shift;

    my $bar = $req->param( "bar" ); # this dies

    return {
        -content => "Got me wrong",
    };
});

neaf->route( bar => sub {
    my $req = shift;

    my $bar = $req->param( bar => qr/.*/ );

    return {
        data => $bar,
    };
}, -template => \"[% data %]", -view => 'foo' );

my $code = neaf->run;

is (ref $code, 'CODE', "run returns sub in scalar context");

my %request = (
    REQUEST_METHOD => 'GET',
    REQUEST_URI => "/",
    QUERY_STRING => "bar=137",
    SERVER_PROTOCOL => "HTTP/1.0",
);

my $root = $code->( \%request ); # not found
note explain $root;
is (scalar @$root, 3, "PSGI-compatible");
is ($root->[0], 404, "Root not found");

{
    my @warn;
    local $SIG{__WARN__} = sub { push @warn, $_[0] };

    $request{REQUEST_URI} = "/foo";
    my $foo = $code->( \%request );
    note explain $foo;
    is (scalar @$foo, 3, "PSGI-compatible");
    is ($foo->[0], 500, "Failed request");
    is (scalar @warn, 1, "1 warn issued");
    like ($warn[0], qr/ERROR.*foo.*MVC::Neaf::Request::PSGI->param/
        , "Warning as expected");
    note "WARN: $_" for @warn;
};

$request{REQUEST_URI} = "/bar";
my $bar = $code->( \%request );
note explain $bar;
is (scalar @$bar, 3, "PSGI-compatible");
is ($bar->[0], 200, "Normal request");
is_deeply ($bar->[2], [137], "Content is fine");


note "INTROSPECTION";

is_deeply (neaf->get_routes( sub { 1 } ), {
    '/foo' => { GET => 1, POST => 1, HEAD => 1 },
    '/bar' => { GET => 1, POST => 1, HEAD => 1 },
}, "Callback that returns true reveals tree");

is_deeply (neaf->get_routes( sub { $_[2] eq 'GET' } ), {
    '/foo' => { GET => 1 },
    '/bar' => { GET => 1 },
}, "Callback acts as filter");

my $map = neaf->get_routes;
is $map->{'/bar'}{GET}{path_info_regex}, qr(^$), "No callback => everything";
is $map->{'/foo'}{GET}{path_info_regex}, qr(^$), "No callback => everything (2)";

done_testing;
