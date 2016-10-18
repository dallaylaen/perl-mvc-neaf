package MVC::Neaf::CLI;

use strict;
use warnings;
our $VERSION = 0.0901;

=head1 NAME

MVC::Neaf::CLI - Command line debugger for Not Even A Framework

=head1 DESCRIPTION

Run your applications from command line, with various overrides.

This is only useful for debugging, slightly better than CGI.pm's though.

=head1 SINOPSYS

    perl application.pl --post /foo/bar arg=42

=head1 OPTIONS

=over

=item * --post - set method to POST.

=item * --method METHOD - set method to anything else.

=item * --upload id=/path/to/file - add upload. Requires --post.

=item * --cookie name="value" - add cookie.

=item * --header name="value" - set http header.

=item * --view - force (JS,TT,Dumper) view.

=item * --list - don't process request, instead print routes
configured in the application.

=item * --help - don't process request, instead display a brief
usage message

=back

=head2 METHODS

The usage doesn't expect these are called directly.

But just for the sake of completeness...

=cut

use Getopt::Long;
use Carp;
use HTTP::Headers;

use MVC::Neaf;
use MVC::Neaf::Request::CGI;
use MVC::Neaf::Upload;

=head2 run()

Run the application.
This reads command line options, as shown in the summary above.

B<NOTE> Spoils @AGRV.

=cut

sub run {
    my $self = shift;

    my $todo = "run";
    my %opt;
    my @upload;
    my @cookie;
    my @head;
    my $view;

    GetOptions(
        "help"      => \&usage,
        "list"      => sub { $todo = "list" },
        "post"      => sub { $opt{method} = 'POST' },
        "method=s"  => \$opt{method},
        "upload=s"  => \@upload,
        "cookie=s"  => \@cookie,
        "header=s"  => \@head,
        "view=s"    => \$view,
        # TODO --session to reduce hassle
    ) or croak "Unknown command line arguments given to MVC::Neaf::CLI";

    $opt{method} = uc $opt{method} if $opt{method};

    croak "--upload requires --post"
        if @upload and $opt{method} ne 'POST';

    if ($todo eq 'list') {
        return $self->list;
    };

    foreach (@upload) {
        /^(\w+)=(.+)$/ or croak "Usage: --upload key=/path/to/file";
        my ($key, $file) = ($1, $2);

        open my $fd, "<", $file
            or die "Failed to open upload $key file $file: $!";

        $opt{uploads}{$key} = MVC::Neaf::Upload->new(
            id => $key, handle => $fd );
    };

    foreach (@cookie) {
        /^(\w+)=(.*)$/
            or croak "Usage: --cookie name=value";

        $opt{neaf_cookie_in}{$1} = $2;
    };

    if (@head) {
        $opt{header_in} = HTTP::Headers->new (
            map { /^([^=]+)=(.*)$/ or croak "Bad header format"; $1=>$2 } @head
        );
    };


    # Create and mangle the request
    my $req = MVC::Neaf::Request::CGI->new(%opt);
    if ($ARGV[0] and $ARGV[0] =~ m#/(.*?)(?:\?|$)#) {
        $req->set_full_path($1);
    } else {
        $req->set_full_path("/");
    };

    # Run the application
    MVC::Neaf->set_forced_view( $view ) if $view;
    my $unused = MVC::Neaf->run(); # warm up caches
    MVC::Neaf->handle_request( $req );
};

=head2 usage()

Display help message and exit(0).

B<NOTE> exit() used.

=cut

sub usage {
    my $pack = __PACKAGE__;

    print <<"USAGE";
Usage: perl -M$pack [options] <your-script> <param=value>
RRun a Neaf application from command line with variour parameters altered.
Options may include:
    --post - set method to POST
    --method METHOD - set method to anything else
    --upload id=/path/to/file - add upload. Requires --post.
    --cookie name="value" - add cookie.
    --header name="value" - set http header.
    --view - force (JS,TT,Dumper) view.
    --list - print routes configured in the application.
    --help - this message
See `perldoc $pack` for more.
USAGE

    exit 0; # Yes, MVC::Neaf::CLI->usage() will exit deliberately.
};

=head2 list()

List registered Neaf routes.

=cut

sub list {
    my ($self, $req) = @_;

    my $routes = MVC::Neaf->get_routes;

    foreach( sort keys %$routes ) {
        my $profile = $routes->{$_};
        my $method = $profile->{allowed_methods}
            ? " [".(join ",", keys %{ $profile->{allowed_methods} })."]"
            : "";

        my $descr = $profile->{description} ? " # $profile->{description}" : "";
        my $path = $_ || '/';

        print "$path$method$descr\n";
    };
};

1;


