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

use lib "$Bin/lib";
use MVC::Neaf;

# skipping 05-lang for now - won't work under apache as CGI
my $dir = "$Bin/nocommit-apache";
my $conf = "$dir/httpd.conf";
my $port_cgi = 8000;
my $port_perl = 8001;
# TODO autodetect free ports

my $HTTPD_CONF = <<"TT";
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


Listen [% port_cgi %]
Listen [% port_perl %]
ErrorLog [% dir %]/error.log

<VirtualHost *:[% port_cgi %]>
    ServerName localhost

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
</VirtualHost>

####################
#   mod_perl part  #
####################
<VirtualHost *:[% port_perl %]>
    ServerName perl.localhost

[% FOREACH item IN public %]
PerlPostConfigRequire [% item.caller.1 %]
[% END %]
<Location /cgi>
    SetHandler perl-script
    PerlResponseHandler MVC::Neaf::Request::Apache2
</Location>
</VirtualHost>

TT

my $INDEX_HTML = <<"TT";
<html>
<head>
    <title>Index of examples</title>
</head>
<body>
<h1>Index of examples</h1>
<ul>
[% FOREACH item IN public %]
    <li>
    <a href="[% item.path %]">[% item.path %] - [% item.description %]</a><br>
    </li>
[% END %]
</ul>
</body>
</html>
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
foreach (qw(/ html forms)) {
    -d "$dir/$_" or mkdir "$dir/$_"
        or die "Failed to mkdir $dir/$_: $!";
};

symlink "$Bin/example", "$dir/cgi";
my $err = $!;
-l "$dir/cgi" or die "Failed to symlink $dir/cgi -> $Bin/example: $err";

# Autogenerate example index
my $n;
foreach my $file (glob "$Bin/example/*.pl") {
    $n++;
    eval "package My::Isolated::$n; require \$file;";
    if ($@) {
        warn "Failed to load $file: $@";
        next;
    };
};

my $list = MVC::Neaf->get_routes();
my @public = sort { $a->{path} cmp $b->{path} }
    grep { $_->{description} }
    grep { $_->{path} =~ m,^/cgi/, }
    values %$list;

# Process conf template
my %vars = (
    lib       => "$Bin/lib",
    dir       => "$dir",
    port_cgi  => $port_cgi,
    port_perl => $port_perl,
    parent    => $Bin,
    modules   => $modules,
    magic     => $magic,
    public    => \@public,
);

my $tt = Template->new;
open my $fd, ">", $conf
    or die "Failed to open(w) apache config $conf: $!";
$tt->process ( \$HTTPD_CONF, \%vars, $fd);
close $fd or die "Failed to close $conf: $!";

# Process index template
open my $fd_idx, ">", "$dir/html/index.html"
    or die "Failed to create $dir/html/index.html: $!";
$tt->process( \$INDEX_HTML, { public => \@public }, $fd_idx )
    or warn "Failed to create index file: ".$tt->error;
close ($fd_idx);

# restart server if asked to
if ($action eq 'start' and -x $httpd) {
    # First, wait for stop above to take effect
    print "Waiting for port $port_cgi to clear...\n";
    wait_for_port( $port_cgi, 0 );
    print "Port $port_cgi free, starting $httpd\n";

    system $httpd, -f => $conf, -k => "start";
    print "Check logs at $dir/error.log\n";

    if ($?) {
        print "Server start failed!\n";
        exit 1;
    };

    print "Waiting for port $port_cgi to become active\n";
    wait_for_port( $port_cgi, 1 );

    print "Check plain server at http://localhost:$port_cgi/\n";
    print "Check mod_perl server at http://localhost:$port_perl/\n";
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
