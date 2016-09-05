package MVC::Neaf::Request;

use strict;
use warnings;

our $VERSION = 0.0503;

=head1 NAME

MVC::Neaf::Request - Request class for Neaf.

=head1 DESCRIPTION

This is what your application is going to get as its ONLY input.

Here's a brief overview of what a Neaf request returns:

    # How the application was configured:
    MVC::Neaf->route( "/matching/route" => sub { my $req = shift; ... } );

    # What was requested:
    http(s)://server.name:1337/mathing/route/some/more/slashes?foo=1&bar=2

    # What is being returned:
    $req->http_version = HTTP/1.0 or HTTP/1.1   # UNIMPLEMENTED YET
    $req->scheme       = http or https          # UNIMPLEMENTED YET
    $req->method       = GET
    $req->hostname     = server.name            # UNIMPLEMENTED YET
    $req->port         = 1337                   # UNIMPLEMENTED YET
    $req->path         = /mathing/route/some/more/slashes
    $req->script_name  = /mathing/route
    $req->path_info    = /some/more/slashes

    $req->param( foo => '\d+' ) = 1

=head1 METHODS

The concrete Request object the App gets is going to be a subclass of this.
Thus it is expected to have the following methods.

=cut

use Carp;
use URI::Escape;
use POSIX qw(strftime);
use Encode;

use MVC::Neaf::Upload;
use MVC::Neaf::Exception;

=head2 new( %args )

The application is not supposed to make its own requests,
so this constructor is really for testing purposes only.

For now, just swallows whatever given to it.
Restrictions MAY BE added in the future though.

=cut

sub new {
    my ($class, %args) = @_;
    return bless \%args, $class;
};

# TODO A lot of copypasted methods down here.
# Should we join them all? Maybe...

=head2 client_ip()

Returns the IP of the client. Note this may be mangled by proxy...

=cut

sub client_ip {
    my $self = shift;

    return $self->{client_ip} ||= do {
        my @fwd = $self->header_in( "X-Forwarded-For" );
        @fwd == 1 && $fwd[0] || $self->do_get_client_ip || "127.0.0.1";
    };
};

=head2 http_version()

Returns version number of http protocol.

=cut

sub http_version {
    my $self = shift;

    if (!exists $self->{http_version}) {
        $self->{http_version} = $self->do_get_http_version;
    };

    return $self->{http_version};
};

=head2 scheme()

Returns http or https, depending on how the request was done.

=cut

sub scheme {
    my $self = shift;

    if (!exists $self->{scheme}) {
        $self->{scheme} = $self->do_get_scheme || 'http';
    };

    return $self->{scheme};
};

=head2 secure()

Returns true if https:// is used, false otherwise.

=cut

sub secure {
    my $self = shift;
    return $self->scheme eq 'https';
};

=head2 method()

Return the HTTP method being used.
GET is the default value (useful for CLI debugging).

=cut

sub method {
    my $self = shift;
    return $self->{method} ||= $self->do_get_method || "GET";
};

=head2 hostname()

Returns the hostname which was requested, or "localhost" if cannot detect.

=cut

sub hostname {
    my $self = shift;

    return $self->{hostname} ||= $self->do_get_hostname || "localhost";
    # TODO what if http://0/?
};

=head2 port()

Returns the port number.

=cut

sub port {
    my $self = shift;

    return $self->{port} ||= $self->do_get_port;
};

=head2 path()

Returns the path part of the uri. Path is guaranteed to start with a slash.

=cut

sub path {
    my $self = shift;

    $self->set_full_path
        unless exists $self->{path};

    return $self->{path};
};

=head2 script_name()

The part of the request that mathed the route to the
application being executed.
Guaranteed to start with slash and be a prefix of path().

=cut

sub script_name {
    my $self = shift;

    $self->set_full_path
        unless exists $self->{script_name};

    return $self->{script_name};
};

=head2 path_info( [ $trim = 0|1 ])

Return path_info, the part of URL between script_name and parameters.
Empty if no such part exists.

If trim=1 is given, removed the leading slashes.

=cut

sub path_info {
    my ($self, $trim) = @_;

    return '' unless exists $self->{path_info};

    my $path = $self->{path_info};
    $path =~ s#^/+## if $trim;
    return $path;
};

=head2 set_full_path( $path )

=head2 set_full_path( $script_name, $path_info )

Set new path elements which will be returned from this point onward.

Also updates path() value so that path = script_name + path_info
still holds.

set_full_path(undef) resets script_name to whatever returned
by the underlying driver.

Returns self.

=cut

sub set_full_path {
    my ($self, $script_name, $path_info) = @_;

    if (!defined $script_name) {
        $script_name = $self->do_get_path;
    };

    $script_name =~ s#^/*#/#;
    $self->{script_name} = $script_name;

    if (defined $path_info) {
        # Make sure path_info always has a slash if nonempty
        $path_info = "/$path_info" if $path_info =~ /^[^\/]/;
        $self->{path_info} = Encode::is_utf8($path_info)
                ? $path_info
                : decode_utf8(uri_unescape($path_info));
    } elsif (!defined $self->{path_info}) {
        $self->{path_info} = '';
    };

    $self->{path} = "$self->{script_name}$self->{path_info}";
    return $self;
};

=head2 set_path_info ( $path_info )

Sets path_info to new value.

Also updates path() value so that path = script_name + path_info
still holds.

Returns self.

=cut

sub set_path_info {
    my ($self, $path_info) = @_;

    $path_info = '' unless defined $path_info;
    $path_info = "/$path_info" if $path_info =~ /^[^\/]/;

    $self->{path_info} = $path_info;

    $self->{path} = "$self->{script_name}$self->{path_info}";
    return $self;
};

=head2 param($name, $regex [, $default])

Return param, if it passes regex check, default value (or '') otherwise.

The regular expression is applied to the WHOLE string,
from beginning to end, not just the middle.
Use '.*' if you really need none.

A default value of C<undef> is possible, but must be supplied explicitly.

=cut

sub param {
    my ($self, $name, $regex, $default) = @_;

    croak( (ref $self)."->param: validation regex is REQUIRED")
        unless defined $regex;
    $default = '' if @_ <= 3; # deliberate undef as default = ok

    # Some write-through caching
    my $value = (exists $self->{cached_params}{ $name })
        ? $self->{cached_params}{ $name }
        : ( $self->{cached_params}{ $name }
            = decode_utf8( $self->_all_params->{ $name } ) );

    return (defined $value and $value =~ /^$regex$/s)
        ? $value
        : $default;
};

=head2 set_param( name => $value )

Override form parameter. Returns self.

=cut

sub set_param {
    my ($self, $name, $value) = @_;

    $self->{cached_params}{$name} = $value;
    return $self;
};

=head2 get_form_as_hash ( name => qr/.../, name2 => qr/..../, ... )

Return a group of form parameters as a hashref.
Only values that pass corresponding validation are added.

B<EXPERIMANTAL>. API and naming subject to change.

=cut

sub get_form_as_hash {
    my ($self, %spec) = @_;

    my %form;
    foreach (keys %spec) {
        my $value = $self->param( $_, $spec{$_}, undef );
        $form{$_} = $value if defined $value;
    };

    return \%form;
};

=head2 get_form_as_list ( qr/.../, qw(name1 name2 ...)  )

=head2 get_form_as_list ( [ qr/.../, "default" ], qw(name1 name2 ...)  )

Return a group of form parameters as a list, in that order.
Values that fail validation are returned as undef, unless default given.

B<EXPERIMANTAL>. API and naming subject to change.

=cut

sub get_form_as_list {
    my ($self, $spec, @list) = @_;

    # TODO Should we?
    croak "Meaningless call of get_form_as_list() in scalar context"
        unless wantarray;

    $spec = [ $spec, undef ]
        unless ref $spec eq 'ARRAY';

    # Call the same validation over for each parameter
    return map { $self->param( $_, @$spec ); } @list;
};

sub _all_params {
    my $self = shift;

    return $self->{all_params} ||= $self->do_get_params;
};

=head2 set_default( key => $value, ... )

Set default values for your return hash.
May be useful inside MVC::Neaf->pre_route.

Returns self.

B<EXPERIMANTAL>. API and naming subject to change.

=cut

sub set_default {
    my ($self, %args) = @_;

    foreach (keys %args) {
        defined $args{$_}
            ? $self->{defaults}{$_} = $args{$_}
            : delete $self->{defaults}{$_};
    };

    return $self;
};

=head2 get_default()

Returns a hash of previously set default values.

=cut

sub get_default {
    my $self = shift;

    return $self->{defaults} || {};
};

=head2 upload( "name" )

=cut

sub upload {
    my ($self, $id) = @_;

    # caching undef as well, so exists()
    if (!exists $self->{uploads}{$id}) {
        my $raw = $self->do_get_upload( $id );
        # This would create NO upload objects for objects
        # And also will return undef as undef - just as we want
        #    even though that's side effect
        $self->{uploads}{$id} = (ref $raw eq 'HASH')
            ? MVC::Neaf::Upload->new( %$raw, id => $id )
            : $raw;
    };

    return $self->{uploads}{$id};
};

=head2 get_cookie ( "name" => qr/regex/ [, "default" ] )

Fetch client cookie.
The cookie MUST be sanitized by regular expression.

The regular expression is applied to the WHOLE string,
from beginning to end, not just the middle.
Use '.*' if you really need none.

=cut

sub get_cookie {
    my ($self, $name, $regex, $default) = @_;

    $default = '' unless defined $default;
    croak( (ref $self)."->get_cookie: validation regex is REQUIRED")
        unless defined $regex;

    $self->{neaf_cookie_in} ||= do {
        my %hash;
        foreach ($self->header_in("cookie")) {
            /^(\S+?)=(.*)/ or next;
            $hash{$1} = decode_utf8(uri_unescape($2));
        };
        \%hash;
    };
    my $value = $self->{neaf_cookie_in}{ $name };
    return $default unless defined $value;

    if (!Encode::is_utf8($value)) {
        # HACK non-utf8 => do what the driver forgot.
        $value = decode_utf8( $value );
        $self->{neaf_cookie_in}{ $name } = $value;
    };

    return $value =~ /^$regex$/ ? $value : $default;
};

=head2 set_cookie( name => "value", %options )

Set HTTP cookie. %options may include:

=over

=item * regex - regular expression to check outgoing value

=item * ttl - time to live in seconds

=item * expires - unix timestamp when the cookie expires
(overridden by ttl).

=item * domain

=item * path

=item * httponly - flag

=item * secure - flag

=back

Returns self.

=cut

sub set_cookie {
    my ($self, $name, $cook, %opt) = @_;

    defined $opt{regex} and $cook !~ /^$opt{regex}$/
        and croak "set_cookie(): constant value doesn't match regex";

    if (defined $opt{ttl}) {
        $opt{expires} = time + $opt{ttl};
    };

    $self->{neaf_cookie_out}{ $name } = [
        $cook, $opt{regex},
        $opt{domain}, $opt{path}, $opt{expires}, $opt{secure}, $opt{httponly}
    ];

    # TODO also set cookie_in for great consistency, but don't
    # break reading cookies from backend by cache vivification!!!
    return $self;
};

# Set-Cookie: SSID=Ap4P….GTEq; Domain=foo.com; Path=/;
# Expires=Wed, 13 Jan 2021 22:23:01 GMT; Secure; HttpOnly

=head2 format_cookies

Converts stored cookies into an arrayref of scalars
ready to be put into Set-Cookie header.

=cut

sub format_cookies {
    my $self = shift;

    my $cookies = $self->{neaf_cookie_out} || {};

    my @out;
    foreach my $name (keys %$cookies) {
        my ($cook, $regex, $domain, $path, $expires, $secure, $httponly)
            = @{ $cookies->{$name} };
        next unless defined $cook; # TODO erase cookie if undef?

        $path = "/" unless defined $path;
        defined $expires and $expires
             = strftime( "%a, %d %b %Y %H:%M:%S GMT", gmtime($expires));
        my $bake = join "; ", ("$name=".uri_escape_utf8($cook))
            , defined $domain  ? "Domain=$domain" : ()
            , "Path=$path"
            , defined $expires ? "Expires=$expires" : ()
            , $secure ? "Secure" : ()
            , $httponly ? "HttpOnly" : ();
        push @out, $bake;
    };
    return \@out;
};

=head2 error ( status )

Report error to the CORE.

This throws an MVC::Neaf::Exception object.

If you're planning calling $req->error within eval block,
consider using neaf_err function to let it propagate:

    use MVC::Neaf::Exception qw(neaf_err);

    eval {
        $req->error(422)
            if ($foo);
        $req->redirect( "http://google.com" )
            if ($bar);
    };
    if ($@) {
        neaf_err($@);
        # The rest of the catch block
    };

=cut

sub error {
    my $self = shift;
    die MVC::Neaf::Exception->new(@_);
};

=head2 redirect( $location )

Redirect to a new location.

This throws an MVC::Neaf::Exception object.
See C<error()> dsicussion above.

=cut

sub redirect {
    my ($self, $location) = @_;

    die MVC::Neaf::Exception->new(
        -status => 302,
        -location => $location,
    );
};

=head2 header_in()

=head2 header_in( "header_name" )

Fetch HTTP header sent by client.
Header names are lowercased, dashes converted to underscores.
So "Http-Header", "HTTP_HEADER" and "http_header" are all the same.

Without argument, returns a L<HTTP::Headers> object.

With a name, returns all values for that header in list context,
or ", " - joined value as one scalar in scalar context -
this is actually a frontend to HTTP::Headers header() method.

B<EXPERIMENTAL> The return value format MAY change in the near future.

=cut

sub header_in {
    my ($self, $name) = @_;

    $self->{header_in} ||= $self->do_get_header_in;
    return $self->{header_in} unless defined $name;

    $name = lc $name;
    $name =~ s/-/_/g;
    return $self->{header_in}->header( $name );
};

=head2 header_in_keys ()

Return all keys in header_in object as a list.

B<EXPERIMENTAL>. This may change or disappear altogether.

=cut

sub header_in_keys {
    my $self = shift;

    my $head = $self->header_in;
    my %hash;
    $head->scan( sub {
        my ($k, $v) = @_;
        $hash{$k}++;
    } );

    return keys %hash;
};

=head2 referer

Get/set referer.

B<NOTE> Avoid using referer for anything serious - too easy to forge.

=cut

sub referer {
    my $self = shift;
    if (@_) {
        $self->{referer} = shift
    } else {
        return $self->{referer} ||= $self->header_in( "referer" );
    };
};

=head2 user_agent

Get/set user_agent.

B<NOTE> Avoid using user_agent for anything serious - too easy to forge.

=cut

sub user_agent {
    my $self = shift;
    if (@_) {
        $self->{user_agent} = shift
    } else {
        $self->{user_agent} = $self->header_in("user_agent")
            unless exists $self->{user_agent};
        return $self->{user_agent};
    };
};

=head2 postpone( CODEREF->(req) )

Execute a function right after the request is served.

Can be called multiple times.

B<CAVEAT>: If CODEREF contains reference to the request,
the request will never be destroyed due to circular reference.
Thus CODEREF may not be executed.

Don't pass request to CODEREF, use C<my $req = shift>
instead if really needed.

Returns self.

=cut

sub postpone {
    my ($self, $code) = @_;

    ref $code eq 'CODE'
        or croak( (ref $self)."->postpone(): argument must be a function" );

    push @{ $self->{postpone} }, $code;
    return $self;
};

=head2 execute_postponed()

NOT TO BE CALLED BY USER.

Execute postponed functions. This is called in DESTROY by default,
but request driver may decide it knows better.

Flushes postponed queue. Ignores exceptions in functions being executed.

Returns self.

=cut

sub execute_postponed {
    my $self = shift;

    my $todo = delete $self->{postpone};
    foreach my $code (@$todo) {
        # avoid dying in DESTROY, as well as when serving request.
        eval { $code->($self); };
        carp "WARN ".(ref $self).": postponed action failed: $@"
            if $@;
    };
    return $self;
};

sub DESTROY {
    my $self = shift;

    $self->execute_postponed
        if (exists $self->{postpone});
};

=head1 DRIVER METHODS

The following methods MUST be implemented in every Request subclass
to create a working Neaf backend.

They shall not generally be called directly inside the app.

=over

=item * do_get_client_ip()

=item * do_get_http_version()

=item * do_get_method()

=item * do_get_scheme()

=item * do_get_hostname()

=item * do_get_port()

=item * do_get_path()

=item * do_get_params()

=item * do_get_upload()

=item * do_get_header_in() - returns a HTTP::Headers object.

=item * do_reply( $status, \%headers, $content )

=back

=cut

foreach (qw(
    do_get_method do_get_scheme do_get_hostname do_get_port do_get_path
    do_get_client_ip do_get_http_version
    do_get_params do_get_upload do_get_header_in
    do_reply )) {
    my $method = $_;
    my $code = sub {
        my $self = shift;
        croak ((ref $self || $self)."->$method() unimplemented!");
    };
    no strict 'refs'; ## no critic
    *$method = $code;
};

1;
