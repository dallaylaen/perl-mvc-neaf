#!/usr/bin/env perl

###########################################
#  This script provides ability to test Neaf
#  under the Apache2 web server.
#  It creates a temp directory and puts a server
#  config there, starting it if possible.
#  It also symlinks the example/ directory content
#  into apache's cgi dir, allowing to test
#  CGI behaviour in real life.

use strict;
use warnings;
use FindBin qw($Bin);
use Template;

my $action = shift || '';
if ($action !~ /^(start|stop|make)$/) {
	print "Usage: $0 start|stop|make";
	exit 0;
};

my $tpl = <<"TT";
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
TypesConfig  magic

Listen [% port %]
ErrorLog [% dir %]/error.log

<Location />
</Location>

Alias /forms [% dir %]/forms
<Directory [% dir %]/forms>
	SetEnv PERL5LIB [% lib %]
	AddHandler cgi-script cgi pl neaf
	Options +Indexes +ExecCGI +FollowSymlinks
</Directory>

Alias /cgi [% dir %]/cgi
<Directory [% dir %]/cgi>
	SetEnv PERL5LIB [% lib %]
	AddHandler cgi-script cgi pl neaf
	Options +Indexes +ExecCGI +FollowSymlinks
</Directory>

TT

my $dir = "$Bin/nocommit-apache";
my $conf = "$dir/httpd.conf";
my $httpd = "/usr/sbin/apache2"; # TODO hardcode, autodetect!
chomp $httpd;
my $port = 8000;

# Stop apache
system $httpd, -f => $conf, -k => "stop"
	if -f $conf and -x $httpd;

# Create dirs if needed
foreach (qw(/ cgi html forms)) {
	-d "$dir/$_" or mkdir "$dir/$_"
		or die "Failed to mkdir $dir/$_: $!";
};

# Create links to examples
# /forms/ is just the same, but does not spoil our shiny index
my %cgi = (qw(
	01-get 01-hello-get.neaf
	02-post 02-cookie-post-redirect.neaf
	forms/02-post 02-cookie-post-redirect.neaf
));

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
	modules   => "/usr/lib/apache2/modules",
);

my $tt = Template->new;
open my $fd, ">", $conf
	or die "Failed to open(w) apache config $conf: $!";
$tt->process ( \$tpl, \%vars, $fd);
close $fd or die "Failed to close $conf: $!";

# restart server if asked to
if ($action eq 'start' and -x $httpd) {
	system $httpd, -f => $conf, -k => "start";
	if (!$?) {
		print "Chack server at http://localhost:$port/cgi/"
	};
};


