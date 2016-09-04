#!/usr/bin/env perl

###########################################
#  This script provides ability to test Neaf
#  under the Apache2 web server.
#  It creates a temp directory and puts a server
#  config there, starting it if possible.
#  It also symlinks the example/ directory content
#  into apache's cgi dir, allowing to test
#  CGI behaviour in real life.

# TODO Now this file is obviously NOT a cgi script.
# However, naming it as apache.pl make MakeMaker install it into the lib
# which was not what I wanted.

use strict;
use warnings;
use FindBin qw($Bin);
use File::Basename qw(dirname);
use Template;
use IO::Socket::INET;
use Time::HiRes qw(sleep);

# Some config here
# /forms/ is just the same, but does not spoil our shiny index
my %cgi = (qw(
    01-get 01-hello-get.pl
    02-post 02-cookie-post-redirect.pl
    forms/02-post 02-cookie-post-redirect.pl
    03-upload 03-upload.pl
    04-image 04-raw-content.pl
    forms/04-img 04-raw-content.pl
    08-header 08-header.pl
    09-request 09-request.pl
));
# skipping 05-lang for now - won't work under apache as CGI
my $dir = "$Bin/nocommit-apache";
my $conf = "$dir/httpd.conf";
my $port = 8000;

my $tpl = <<"TT";
ServerRoot [% dir %]
ServerName localhost
DocumentRoot [% dir %]/html

LogLevel info
PidFile [% dir %]/apache.pid

[% SET modules = modules || "modules" %]
LoadModule alias_module       [% modules %]/mod_alias.so
LoadModule dir_module         [% modules %]/mod_dir.so
LoadModule autoindex_module   [% modules %]/mod_autoindex.so
LoadModule cgi_module         [% modules %]/mod_cgi.so
LoadModule env_module         [% modules %]/mod_env.so
LoadModule mime_module        [% modules %]/mod_mime.so
    # this fixes mod_mime loading on my ubuntu
    TypesConfig [% magic %]
LoadModule perl_module        [% modules %]/mod_perl.so
    PerlSwitches -I[% lib %]
LoadModule apreq_module       [% modules %]/mod_apreq2.so


Listen [% port %]
ErrorLog [% dir %]/error.log

Alias /forms [% dir %]/forms
<Directory [% dir %]/forms>
    SetEnv PERL5LIB [% lib %]
    AddHandler cgi-script cgi pl
    Options +Indexes +ExecCGI +FollowSymlinks
</Directory>

Alias /cgi [% dir %]/cgi
<Directory [% dir %]/cgi>
    SetEnv PERL5LIB [% lib %]
    AddHandler cgi-script cgi pl
    Options +Indexes +ExecCGI +FollowSymlinks
</Directory>

####################
#   mod_perl part  #
####################
PerlModule MVC::Neaf
# PerlPostConfigRequire [% parent %]/example/01-hello-get.pl
# PerlPostConfigRequire [% parent %]/example/03-upload.pl
# <Location /perl>
#    SetHandler perl-script
#    PerlResponseHandler MVC::Neaf::Request::Apache2
# </Location>

PerlSetEnv EXAMPLE_PATH_REQUEST /request/parser
PerlPostConfigRequire [% parent %]/example/09-request.pl
<Location /request/parser>
    SetHandler perl-script
    PerlResponseHandler MVC::Neaf::Request::Apache2
</Location>

TT

# Process command line before doing the heavilifting
my $action = shift || '';
if ($action !~ /^(start|stop|make)$/) {
    print "Usage: $0 start|stop|make";
    exit 0;
};

# Autodetect where Apache sits
# TODO I only have Ubuntu, need input from people with other systems
my $httpd = "/usr/sbin/apache2";
foreach (qw(/usr/sbin/httpd)
    , map { chomp } `which httpd`, `which apache2`, `which apache`) {
    $_ and -x $_ or next;
    $httpd = $_;
    last;
};

my $modules = "/usr/lib/apache2/modules";
foreach (qw(/etc/apache2), dirname($httpd), dirname(dirname($httpd)) ) {
    $_ and -d $_ and -d "$_/modules" and -f "$_/modules/mod_cgi.so" or next;
    $modules = $_;
    last;
};

my $magic = "/etc/apache2/mime.types";
foreach( qw(/etc/apache2/magic), dirname($httpd)."/conf"
    , dirname(dirname($httpd))."/conf", "/etc/magic") {
    $_ and -r $_ and -s $_ or next;
    $magic = $_;
    last;
};

# Stop apache anyway
print "Stopping apache before mangling config...\n";
system $httpd, -f => $conf, -k => "stop"
    if -f $conf and -x $httpd;

# Create dirs if needed
foreach (qw(/ cgi html forms)) {
    -d "$dir/$_" or mkdir "$dir/$_"
        or die "Failed to mkdir $dir/$_: $!";
};

# Create links to examples
foreach (keys %cgi) {
    my $link = /^forms\// ? "$dir/$_.cgi" : "$dir/cgi/$_.cgi";
    my $file = "$Bin/example/$cgi{$_}";
    unlink $link if -e $link;
    symlink $file, $link
        or warn "Failed to symlink $link -> $file, but trying to continue";
};

# Process template
my %vars = (
    lib       => "$Bin/lib",
    dir       => "$dir",
    port      => $port,
    parent    => $Bin,
    modules   => $modules,
    magic     => $magic,
);

my $tt = Template->new;
open my $fd, ">", $conf
    or die "Failed to open(w) apache config $conf: $!";
$tt->process ( \$tpl, \%vars, $fd);
close $fd or die "Failed to close $conf: $!";

# restart server if asked to
if ($action eq 'start' and -x $httpd) {
    # First, wait for stop above to take effect
    print "Waiting for port $port to clear...\n";
    wait_for_port( $port, 0 );
    print "Port $port free, starting $httpd\n";

    system $httpd, -f => $conf, -k => "start";
    print "Check logs at $dir/error.log\n";

    if ($?) {
        print "Server start failed!\n";
        exit 1;
    };

    print "Waiting for port $port to become active\n";
    wait_for_port( $port, 1 );

    print "Check server at http://localhost:$port/cgi/";
};

sub wait_for_port {
    my ($port, $on_off) = @_;

    local $SIG{ALRM} = sub { die "Failed to wait for socket to "
        .($on_off ? "start" : "stop") };
    alarm 10;

    while ( 1 ) {
        my $sock = IO::Socket::INET->new(
            Proto => "tcp",
            PeerHost => "localhost",
            PeerPort => $port,
        );
        close $sock if $sock;

        last unless $sock xor $on_off; # sock and on_off must be both true | both false
        sleep 0.01;
    };
    alarm 0;
};
