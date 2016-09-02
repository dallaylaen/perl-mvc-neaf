package MVC::Neaf::Request;

use strict;
use warnings;

our $VERSION = 0.0401;

=head1 NAME

MVC::Neaf::Request - Base request class for Neaf.

=head1 OVERVIEW

This is what your application is going to get as the only input.

=head1 METHODS

These methods are common for ALL Neaf::Request::* classes.

=cut

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
	return $self->{method} ||= $self->do_get_method || "GET";
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

	return (defined $value and $value =~ /^$regex$/)
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

    $self->{neaf_cookie_in} ||= $self->do_get_cookies;
    return unless $self->{neaf_cookie_in}{ $name };
    my $value = $self->{neaf_cookie_in}{ $name };

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
