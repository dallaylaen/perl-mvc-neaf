package MVC::Neaf;

use 5.006;
use strict;
use warnings;

our $VERSION = 0.06;

=head1 NAME

MVC::Neaf - Not Even A Framework for very simple web apps.

=head1 OVERVIEW

Neaf [ni:f] stands for Not Even An (MVC) Framework.

It is made for lazy people without an IDE.

The Model is assumed to be just a regular Perl module,
no restrictions are put on it.

The Controller is reduced to just one function which receives a Request object
and returns a \%hashref with a mix
of actual data and minus-prefixed control parameters.

The View is expected to have one method, C<render>, receiving such hash
and returning scalar of rendered context.

The principals of Neaf are as follows:

=over

=item * Start out simple, then scale up.

=item * Already on Perl, needn't more magic.

=item * Everything can be configured, nothing needs to be.

=item * It's not software unless you can run it from command line.

=back

=head1 SYNOPSIS

The following application, outputting a greeting, is ready to run
either from under a plack server, or as a standalone script.

    use MVC::Neaf;

    MVC::Neaf->route( "/app" => sub {
        my $req = shift;

        my $name = $req->param( name => qr/[\w\s]+/, "Yet another perl hacker" );

        return {
            -template => \"Hello, [% name %]",
            -type     => "text/plain",
            name      => $name,
        };
    });
    MVC::Neaf->run;

=head1 CREATING AN APPLICATION

The Controller (which is pretty much the only thing to talk about here)
receives a $request object and outputs a \%hash.

It may also die, which will be interpreted as an error 500,
UNLESS error message starts with 3 digits and a whitespace,
in which case this is considered the return status.
E.g. die 404; is a valid method to return "Not Found" right away.

B<The request> is a L<MCV::Neaf::Request> descendant which generally
boils down to:

    my $param  = $request->param ( "param_name"  => qr/.../, "Unset" );
    my $cookie = $request->cookie( "cookie_name" => qr/.../, "Unset" );
    my $file   = $request->upload( "upload_name" );

Note the regexp check - it's mandatory and deliberately so.
Upload content checking is up to the user, though.
See <MVC::Neaf::Upload>.

B<The response> may contain regular keys, typically alphanumeric,
as well as a predefined set of dash-prefixed keys which control
app's behaviour.

I<-Note -that -dash-prefixed -options -look -antique
even to the author of this writing.
They smell like Tk and CGI. They feel so 90's!
However, it looks like a meaningful and B<visible> way to separate
auxiliary parameters from users's data,
without requiring a more complex return structure
(two hashes, array of arrays etc).>

The small but growing list of these -options is as follows:

=over

=item * -callback - Used by JS view module to produce a
L<jsonp|https://en.wikipedia.org/wiki/JSONP> response.
Callback is ignored unless it is a set of identifiers separated by dots,
for security reasons.

=item * -content - Return raw data and skip view processing.
E.g. display generated image.

=item * -continue - A callback which receives the Request object.
It will be executed after the headers and pre-generated content
are served to the client, and may use $req->write( $data )
and $req->close to write more data.

=item * -location - HTTP Location: header.

=item * -status - HTTP status (200, 404, 500 etc).
Default is 200 if the app managed to live through, and 500 if it died.

=item * -template - Set template name for TT (L<Template>-based view).

=item * -type - Content-type HTTP header.
View module may set this parameter if unset.
Default: C<"text/html">.

=item * -view - select B<View> module.
Views are initialized lazily and cached by the framework.
C<TT>, C<JS>, C<Full::Module::Name>, and C<$view_predefined_object>
are currently supported.
New short aliases may be created by
C<MVC::Neaf-E<gt>load_view( "name" => $your_view );>. (See below).

=back

Though more dash-prefixed parameters may be returned
and will be passed to the View module as of current,
they are not guaranteed to work in the future.
Please either avoid them, or send patches.

=head1 APPLICATION API

These methods are generally called during the setup phase of the application.
They have nothing to do with serving the request.

=cut

use Carp;
use Scalar::Util qw(blessed);
use Encode;

use MVC::Neaf::Request;

our $Inst = __PACKAGE__->new;
sub import {
    my ($class, %args) = @_;

    $args{view} and $Inst->{force_view} = $args{view};
};

=head2 route( path => CODEREF, %options )

Creates a new route in the application.
Any incoming request to uri starting with C</path>
(C</path/something/else> too, but NOT C</pathology>)
will now be directed to CODEREF.

Longer paths are GUARANTEED to be checked first.

Dies if same route is given twice.

Exactly one leading slash will be prepended no matter what you do.
(C<path>, C</path> and C</////path> are all the same).

=cut

sub route {
    my $self = shift;

    # HACK!! pack path components together, i.e.
    # foo => bar => \&handle eq "/foo/bar" => \&handle
    my ( $path, $sub );
    while ($sub = shift) {
        last if ref $sub;
        $path .= "/$sub";
    };
    $self->_croak( "Odd number of elements in hash assignment" )
        if @_ % 2;
    my (%args) = @_;
    $self = $Inst unless ref $self;

    # Sanitize path so that we have exactly one leading slash
    # root becomes nothing (which is OK with us).
    $path =~ s#^/*#/#;
    $path =~ s#/+$##;
    $self->_croak( "Attempting to set duplicate handler for path $path" )
        if $self->{route}{ $path };

    # reset cache
    $self->{route_re} = undef;

    my %profile;

    # Do the work
    $profile{code}     = $sub;
    $profile{defaults} = \%args;
    $profile{caller}   = [caller(0)]; # file,line

    if ($args{method}) {
        $args{method} = [ $args{method} ] unless ref $args{method} eq 'ARRAY';
        my %allowed;
        foreach (@{ $args{method} }) {
            $allowed{ uc $_ }++;
        };
        $profile{allowed_methods} = \%allowed;
    };

    if (my $view = $args{view}) {
        if (!ref $view) {
            $view = $self->load_view( $view );
        } elsif (ref $view eq 'CODE') {
            $view = MVC::Neaf::View->new( callback => $view );
        };

        $self->_croak( "view must be a coderef or a MVC::Neaf::View object" )
            unless blessed $view and $view->isa("MVC::Neaf::View");

        $profile{view} = $view;
    };

    $self->{route}{ $path } = \%profile;
    return $self;
};

=head2 pre_route( sub { ... } )

Mangle request before serving it.
E.g. canonize uri or read session cookie.

If the sub returns a MVC::Neaf::Request object in scalar context,
it is considered to replace the original one.
It looks like it's hard to return an unrelated Request by chance,
but beware!

=cut

sub pre_route {
    my ($self, $code) = @_;
    $self = $Inst unless ref $self;

    $self->{pre_route} = $code;
    return $self;
};

=head2 load_view( $view_name )

Load a view module by name.

=cut

my %known_view = (
    TT     => 'MVC::Neaf::View::TT',
    JS     => 'MVC::Neaf::View::JS',
    Dumper => 'MVC::Neaf::View::Dumper',
);
sub load_view {
    my ($self, $view, $module) = @_;
    $self = $Inst unless ref $self;

    $view = $self->{force_view}
        if exists $self->{force_view};
    $view = $self->{-view}
        unless defined $view;

    # Agressive caching FTW!
    return $self->{seen_view}{$view}
        if exists $self->{seen_view}{$view};

    $module ||= $known_view{ $view } || $view;
    if (!ref $module) {
        eval "require $module"; ## no critic
        $self->_croak( "Failed to load view $view: $@" )
            if $@;
        $module = $module->new;
    };

    $self->{seen_view}{$view} = $module;

    return $module;
};

=head2 set_default ( key => value, ... )

Set some default values that would be appended to data hash returned
from any controller on successful operation.
Controller return always overrides these values.

Returns self.

=cut

sub set_default {
    my ($self, %data) = @_;
    $self = $Inst unless ref $self;

    $self->{defaults}{$_} = $data{$_} for keys %data;
    return $self;
};

=head2 server_stat ( MVC::Neaf::X::ServerStat->new( ... ) )

Record server performance statistics during run.

The interface of ServerStat is as follows:

    my $stat = MVC::Neaf::X::ServerStat->new (
        write_threshold_count => 100,
        write_threshold_time  => 1,
        on_write => sub {
            my $array_of_arrays = shift;

            foreach (@$array_of_arrays) {
                # @$_ = (script_name, http_status,
                #       controller_duration, total_duration, start_time)
                # do something with this data
                warn "$_->[0] returned $_->[1] in $_->[3] sec\n";
            };
        },
    );

on_write will be executed as soon as either count data points are accumulated,
or time is exceeded by difference between first and last request in batch.

Returns self.

=cut

sub server_stat {
    my ($self, $obj) = @_;
    $self = $Inst unless ref $self;

    if ($obj) {
        $self->{stat} = $obj;
    } else {
        delete $self->{stat};
    };

    return $self;
};

=head2 on_error( sub { my ($req, $err) = @_ } )

Install custom error handler (e.g. write to log).

=cut

sub on_error {
    my ($self, $code) = @_;
    $self = $Inst unless ref $self;

    if (defined $code) {
        ref $code eq 'CODE'
            or $self->_croak( "Argument MUST be a callback" );
        $self->{on_error} = $code;
    } else {
        delete $self->{on_error};
    };

    return $self;
};

=head2 error_template ( status => { ... } )

Set custom error handler.

Status must be either a 3-digit number (as in HTTP), or "view".
Other allowed keys MAY appear in the future.

The second argument follows the same rules as controller return.

The following fields are expected to exist if this handler fires:

=over

=item * -status - defaults to actual status (e.g. 500);

=item * caller - array with the point where MVC::Neaf->route was set up;

=item * error - in case of exception, this will be the error.

=back

Returns self.

=cut

sub error_template {
    my ($self, $status, $tpl) = @_;
    $self = $Inst unless ref $self;

    $status =~ /^(\d\d\d|view)$/
        or $self->_croak( "1st arg must be http status or a const(see docs)");
    ref $tpl eq 'HASH'
        or $self->_croak( "2nd arg must be hash (just as controller returns)");

    $self->{error_template}{$status} = $tpl;

    return $self;
};

=head2 run()

Run the applicaton.

Returns a (PSGI-compliant) coderef under PSGI.

=cut

sub run {
    my $self = shift;
    $self = $Inst unless ref $self;
    # TODO Better detection still wanted

    $self->{route_re} ||= $self->_make_route_re;

    if (defined wantarray) {
        # The run method is being called in non-void context
        # This is the case for PSGI, but not CGI (where it's just
        # the last statement in the script).

        # PSGI
        require MVC::Neaf::Request::PSGI;
        return sub {
            my $env = shift;
            my $req = MVC::Neaf::Request::PSGI->new( env => $env );
            return $self->handle_request( $req );
        };
    } else {
        # void context - CGI called.
        require MVC::Neaf::Request::CGI;
        my $req = MVC::Neaf::Request::CGI->new;
        $self->handle_request( $req );
    };
};

sub _make_route_re {
    my ($self, $hash) = @_;

    $hash ||= $self->{route};

    my $re = join "|", map { quotemeta } reverse sort keys %$hash;
    return qr{^($re)(/[^?]*)?(?:\?|$)};
};

=head1 INTERNAL API

B<CAVEAT EMPTOR.>

The following methods are generally not to be used,
unless you want something very strange.

=cut


=head2 new(%options)

Constructor. Usually, instantiating Neaf is not required.
But it's possible.

Options are not checked whatsoever.

Just in case you're curious, $MVC::Neaf::Inst is the default instance
that handles MVC::Neaf->... requests.

=cut

sub new {
    my ($class, %opt) = @_;

    $opt{-type}     ||= "text/html";
    $opt{-view}     ||= "TT";
    $opt{defaults}  ||= { -status => 200 };
    $opt{on_error}  ||= sub {
        my ($req, $err, $where) = @_;
        my $msg = "ERROR: ".$req->script_name.": $err";
        if ($where) {
            $msg =~ s/\s+$//s;
            $msg .= " in $where->[1] line $where->[2]";
        };
        warn "$msg\n";
    };

    return bless \%opt, $class;
};

=head2 handle_request( MVC::Neaf::request->new )

This is the CORE of this module.
Should not be called directly - use run() instead.

=cut

sub handle_request {
    my ($self, $req) = @_;
    $self = $Inst unless ref $self;

    exists $self->{stat} and $self->{stat}->record_start;

    # ROUTE REQUEST
    my $route;
    my $data = eval {
        # First, try running the pre-routing callback.
        if (exists $self->{pre_route}) {
            my $new_req = $self->{pre_route}->( $req );
            blessed $new_req and $new_req->isa("MVC::Neaf::Request")
                and $req = $new_req;
        };

        # Run the controller!
        $req->path =~ $self->{route_re} and $route = $self->{route}{$1}
            or die "404\n";
        !exists $route->{allowed_methods}
            or $route->{allowed_methods}{ $req->method }
            or die "405\n";
        $req->set_full_path( $1, $2 );
        return $route->{code}->($req);
    };

    if ($data) {
        # post-process data - fill in request(RD) & global(GD) defaults.
        # TODO fill in per-location defaults, too - but do we need them?
        my $RD = $req->get_default;
        my $GD = $self->{defaults};
        exists $data->{$_} or $data->{$_} = $RD->{$_} for keys %$RD;
        exists $data->{$_} or $data->{$_} = $GD->{$_} for keys %$GD;
    } else {
        # Fall back to error page
        $data = $self->_error_to_reply( $req, $@, $route->{caller} );
    };

    # END ROUTE REQUEST

    exists $self->{stat}
        and $self->{stat}->record_controller($req->script_name);

    # PROCESS REPLY

    # Render content if needed. This may alter type, so
    # produce headers later.
    my ($content, $type);
    if (defined $data->{-content}) {
        $content = $data->{-content};
        $data->{-type} ||= $content =~ /^.{0,512}([^\s\x20-\x7F])/s
            ? 'application/octet-stream' : 'text/plain';
    } else {
        my $view = $self->load_view( $data->{-view} || $route->{view} );
        eval { ($content, $type) = $view->render( $data ); };
        if (!defined $content) {
            warn "ERROR: In view: $@";
            $data = {
                -status => 500,
                -type   => "text/plain",
            };
            $content = "Template error.";
        };
        $data->{-type} ||= $type || 'text/html';
    };

    # Encode content NOW so that we don't lie about its length
    if (Encode::is_utf8( $content )) {
        $content = encode_utf8( $content );
        $data->{-type} .= "; charset=utf-8";
    };

    # Handle headers
    my $headers = $self->make_headers( $data );
    $headers->{'Set-Cookie'} = $req->format_cookies;
    $headers->{'Content-Length'} ||= length $content
        unless $data->{-continue};
    $content = '' if $req->method eq 'HEAD';

    # END PROCESS REPLY

    exists $self->{stat}
        and $self->{stat}->record_finish($data->{-status}, $req);

    # DISPATCH CONTENT

    if ($data->{-continue} and $req->method ne 'HEAD') {
        $req->postpone( $data->{'-continue'}, 1 );
        $req->postpone( sub { $_[0]->write( $content ); }, 1 );
        return $req->do_reply( $data->{-status}, $headers );
    } else {
        return $req->do_reply( $data->{-status}, $headers, $content );
    };

    # END DISPATCH CONTENT
}; # End handle_request()

sub _error_to_reply {
    my ($self, $req, $err, $where) = @_;

    if (blessed $err and $err->isa("MVC::Neaf::Exception")) {
        $err->{-status} ||= 500;
        return $err;
    };

    # A generic error...
    my $status = (!ref $err && $err =~ /^(\d\d\d)/) ? $1 : 500;
    if( !$1 ) {
        exists $self->{on_error}
            and eval { $self->{on_error}->($req, $err, $where) };
        # ignore errors in error handler
        warn "ERROR: Error handler failed: $@"
            if $@;
    };

    if (exists $self->{error_template}{$status}) {
        my %ret = %{ $self->{error_template}{$status} }; # don't spoil the original
        $ret{-status} = $status;
        $ret{caller} = $where;
        $ret{error} = $err;
        return \%ret;
    } else {
        return {
            -status     => $status,
            -type       => 'text/plain',
            -content    => "Error $status",
        };
    };
};

=head2 make_headers( $data )

Extract header data from application reply.

=cut

sub make_headers {
    my ($self, $data) = @_;
    $self = $Inst unless ref $self;

    my %head;
    $head{'Content-Type'} = $data->{-type} || $self->{-type};
    $head{'Location'} = $data->{-location}
        if $data->{-location};

    return \%head;
};

sub _croak {
    my ($self, $msg) = @_;

    my $where = [caller(0)]->[3];
    croak( (ref $self || $self)."->$where: $msg" );
};

=head1 AUTHOR

Konstantin S. Uvarin, C<< <khedin at gmail.com> >>

=head1 BUGS

Lots of them, this is ALPHA software.

Please report any bugs or feature requests to C<bug-mvc-neaf at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=MVC-Neaf>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc MVC::Neaf


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=MVC-Neaf>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/MVC-Neaf>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/MVC-Neaf>

=item * Search CPAN

L<http://search.cpan.org/dist/MVC-Neaf/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2016 Konstantin S. Uvarin.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of MVC::Neaf
