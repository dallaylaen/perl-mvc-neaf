#!/usr/bin/env perl

use strict;
use warnings;

# always use latest & greatest Neaf
use File::Basename qw(basename dirname);
my $Bin;
BEGIN { $Bin = dirname( __FILE__ ) || "." };
use lib $Bin."/../lib";
use MVC::Neaf;
use MVC::Neaf::X::Session;

my $script = basename(__FILE__);
my $storage = "$Bin/nocommit-$script-storage";

mkdir $storage; # ignore result
-d $storage or die "Failed to find directory '$storage' ($!)";

# Let's make an in-place file-based storage class
{
    package My::Session;
    use parent qw(MVC::Neaf::X::Session);

    use JSON::XS;
    use URI::Escape;

    sub save_session {
        my ($self, $key, $data) = @_;
        my $file = "$storage/".uri_escape($key);
        open my $fd, ">", $file
            or die "Failed to write to $file: $!";
        print $fd encode_json( $data );
        close $fd; # TODO must handle there errors too, riiiiight?
    };
    sub load_session {
        my ($self, $key) = @_;
        my $file = "$storage/".uri_escape($key);
        open my $fd, "<", $file
            or return {};
        local $/;
        return decode_json(<$fd>);
    };
    sub delete_session {
        my ($self, $key) = @_;
        my $file = "$storage/".uri_escape($key);
        unlink $file; # ignore errors
    };
};

MVC::Neaf->set_session_handler( engine => My::Session->new );

my $tpl_main = <<"TT";
<html>
<head><title>Session example</title></head>
<body>
<h1>Session example</h1>
<h2>Hello, [% user || "Stranger" %]</h2>
<form action="/cgi/$script/login" method="POST">
    <input name="user">
    <input type="submit" value="Log in!">
</form>
[% IF user %]
<br>
<form action="/cgi/$script/logout" method="POST">
    <input type="submit" value="Log out">
</form>
[% END %]
</body>
</html>
TT

MVC::Neaf->route( cgi => $script => sub {
    my $req = shift;

    return {
        -template => \$tpl_main,
        user => $req->session->{user},
    };
}, description => "File-based session example" );

MVC::Neaf->route( cgi => $script => login => sub {
    my $req = shift;

    my $user = $req->param( user => qr/\w+/ );

    if ($user) {
        $req->session->{user} = $user;
        $req->save_session;
    };

    $req->redirect( "/cgi/$script" );
}, method => "POST" );

MVC::Neaf->route( cgi => $script => logout => sub {
    my $req = shift;

    $req->delete_session;
    $req->redirect( "/cgi/$script" );
}, method => "POST" );

# TODO logout as well

MVC::Neaf->run;
