package MVC::Neaf::Request;

use strict;
use warnings;

=head1 NAME

MVC::Neaf::Request - Base request class for Neaf.

=head1 METHODS

These methods are common for ALL Neaf::Request::* classes.

=cut

our $VERSION = 0.0105;
use Carp;
use URI::Escape;
use POSIX qw(strftime);

=head2 new( %args )

For now, just swallows whatever given to it.

=cut

sub new {
	my ($class, %args) = @_;
	return bless \%args, $class;
};

=head2 method()

=cut

sub method {
	my $self = shift;
	return $self->{method} ||= $self->do_get_method;
};

=head2 path()

Returns the path part of the uri.

=cut

sub path {
	my $self = shift;

	return $self->{path} ||= do {
		my $path = $self->get_path;
		$path = '' unless defined $path;
		$path =~ s#^/*#/#;
		$self->{original_path} = $path;
		$path;
	};
};

=head2 set_path

Set new path which will be returned onward.
Undef value resets the path to whatever returned by the underlying driver.

=cut

sub set_path {
	my ($self, $path) = @_;

	$path = $self->get_path
		unless defined $path;
	$path =~ s#^/*#/#;

	$self->{path} = $path;
};

=head2 param($name, [$regex, $default])

Return param, if it passes regex check, default value (or '') otherwise.

=cut

sub param {
	my ($self, $name, $regex, $default) = @_;

	my $value = $self->all_params->{ $name };
	$default = '' unless defined $default;

	return (defined $value and $value =~ /^$regex$/)
		? $value
		: $default;
};

=head2 all_params()

Get all params as one hashref via cache.
Loading is performed by get_params() method.

=cut

sub all_params {
	my $self = shift;

	return $self->{all_params} ||= $self->get_params;
};

=head2 get_cookie ( "name" [ => qr/regex/ ] )

Fetch client cookie.

=cut

sub get_cookie {
    my ($self, $name, $regex) = @_;

    $self->{neaf_cookie_in} ||= $self->do_get_cookies;
    return unless $self->{neaf_cookie_in}{ $name };
    my $value = uri_unescape( $self->{neaf_cookie_in}{ $name } );
    defined $regex and $value !~ /^$regex$/ and $value = undef;

    return $value;
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

=cut

sub set_cookie {
    my ($self, $name, $cook, %opt) = @_;

    defined $opt{regex} and $cook !~ /^$opt{regex}$/
        and croak "set_cookie(): constant value doesn't match regex";

    if (defined $opt{ttl}) {
        $opt{expires} = time + $opt{ttl};
    };

    $self->{neaf_cookie_out}{ $name } = [ $cook, $opt{regex}, $opt{domain}, $opt{path}, $opt{expires}, $opt{secure}, $opt{httponly} ];
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
        my $bake = join "; ", ("$name=".uri_escape($cook))
            , defined $domain  ? "Domain=$domain" : ()
            , "Path=$path"
            , defined $expires ? "Expires=$expires" : ()
            , $secure ? "Secure" : ()
            , $httponly ? "HttpOnly" : ();
        push @out, $bake;
    };
    return \@out;
};


=head2 redirect( $location )

Redirect to a new location, currently by dying.

=cut

sub redirect {
	my ($self, $location) = @_;

	die {
		-status => 302,
		-location => $location,
	};
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
		$self->{referer} = $self->do_get_referer
			unless exists $self->{referer};
		return $self->{referer};
	};
};

=head1 DRIVER METHODS

The following methods MUST be implemented in every Request subclass
to create a working Neaf backend.

They shall not generally be called directly inside the app.

=over

=item * do_get_method()

=item * get_path()

=item * get_params()

=item * do_get_cookies()

=item * do_get_referer() - unlike others, this won't die if unimplemented

=item * reply( $status, \%headers, $content )

=back

=cut

foreach (qw(do_get_method get_params do_get_cookies get_path reply)) {
	my $method = $_;
	my $code = sub {
		my $self = shift;
		croak ((ref $self || $self)."->$method() unimplemented!");
	};
	no strict 'refs'; ## no critic
	*$method = $code;
};

sub do_get_referer {
	return '';
};

1;
