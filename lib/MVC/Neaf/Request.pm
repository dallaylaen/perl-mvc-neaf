package MVC::Neaf::Request;

use strict;
use warnings;

=head1 NAME

MVC::Neaf::Request - Base request class for Neaf.

=head1 OVERVIEW

This is what your application is going to get as the only input.

=head1 METHODS

These methods are common for ALL Neaf::Request::* classes.

=cut

our $VERSION = 0.0204;
use Carp;
use URI::Escape;
use POSIX qw(strftime);
use Encode;

use MVC::Neaf::Upload;

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
		my $path = $self->do_get_path;
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

	$path = $self->do_get_path
		unless defined $path;
	$path =~ s#^/*#/#;

	$self->{path} = $path;
};

=head2 param($name, [$regex, $default])

Return param, if it passes regex check, default value (or '') otherwise.

=cut

sub param {
	my ($self, $name, $regex, $default) = @_;

	$default = '' unless defined $default;
	croak( (ref $self)."->param REQUIRES regex for data")
		unless defined $regex;

	# Some write-through caching
	my $value = (exists $self->{cached_params}{ $name })
		? $self->{cached_params}{ $name }
		: ( $self->{cached_params}{ $name }
			= decode_utf8( $self->all_params->{ $name } ) );

	return (defined $value and $value =~ /^$regex$/)
		? $value
		: $default;
};

=head2 set_param( name => $value )

Override form parameter. Returns request object.

=cut

sub set_param {
	my ($self, $name, $value) = @_;

	$self->{cached_params}{$name} = $value;
	return $self;
};

=head2 all_params()

Get all params as one hashref via cache.
Loading is performed by get_params() method.

=cut

sub all_params {
	my $self = shift;

	return $self->{all_params} ||= $self->do_get_params;
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

=head2 get_cookie ( "name" [ => qr/regex/ ] )

Fetch client cookie.

=cut

sub get_cookie {
    my ($self, $name, $regex) = @_;

    $self->{neaf_cookie_in} ||= $self->do_get_cookies;
    return unless $self->{neaf_cookie_in}{ $name };
    my $value = $self->{neaf_cookie_in}{ $name };

	if (!Encode::is_utf8($value)) {
		# HACK non-utf8 => do what the driver forgot.
		$value = decode_utf8( $value );
		$self->{neaf_cookie_in}{ $name } = $value;
	};

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

=item * do_get_path()

=item * do_get_params()

=item * do_get_cookies()

=item * do_get_upload()

=item * do_get_referer() - unlike others, this won't die if unimplemented

=item * do_reply( $status, \%headers, $content )

=back

=cut

foreach (qw(do_get_method do_get_params do_get_cookies do_get_path do_reply do_get_upload )) {
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
