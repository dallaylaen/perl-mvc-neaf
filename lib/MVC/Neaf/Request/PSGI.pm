package MVC::Neaf::Request::PSGI;

use strict;
use warnings;

=head1 NAME

MVC::Neaf::Request::PSGI - Not Even A Framework: PSGI driver.

=head1 METHODS

=cut

our $VERSION = 0.0403;
use URI::Escape qw(uri_unescape);
use Encode;
use Plack::Request;

use parent qw(MVC::Neaf::Request);

=head2 new( env => $psgi_input )

Constructor.

=cut

sub new {
	my $class = shift;
	my $self = $class->SUPER::new( @_ );
	$self->{driver} ||= Plack::Request->new( $self->{env} || {} );
	return $self;
};

=head2 do_get_client_ip

=cut

sub do_get_client_ip {
	my $self = shift;

	return $self->{driver}->address;
};

=head2 do_get_http_version()

=cut

sub do_get_http_version {
	my $self = shift;

	my $proto = $self->{driver}->protocol || 1.0;
	$proto =~ s#^HTTP/##;

	return $proto;
};

=head2 do_get_scheme()

=cut

sub do_get_scheme {
	my $self = shift;
	return $self->{driver}->scheme;
};

=head2 do_get_hostname()

=cut

sub do_get_hostname {
	my $self = shift;
	my $base = $self->{driver}->base;

	return $base =~ m#//([^:?/]+)# ? $1 : "localhost";
};

=head2 do_get_port()

=cut

sub do_get_port {
	my $self = shift;
	my $base = $self->{driver}->base;

	return $base =~ m#//([^:?/]+):(\d+)# ? $2 : "80";
};

=head2 do_get_method()

Return GET/POST.

=cut

sub do_get_method {
	my $self = shift;
	return $self->{driver}->method;
};

=head2 do_get_path()

Returns the path part of URI.

=cut

sub do_get_path {
	my $self = shift;

	my $path = $self->{env}{REQUEST_URI};
	$path = '' unless defined $path;

	$path =~ s#\?.*$##;
	$path =~ s#^/*#/#;

	return $path;
};

=head2 do_get_params()

Returns GET/POST parameters as a hash.

B<CAVEAT> Plack::Request's multivalue hash params are ignored for now.

=cut

sub do_get_params {
	my $self = shift;

	my %hash;
	foreach ( $self->{driver}->param ) {
		$hash{$_} = $self->{driver}->param( $_ );
	};

	return \%hash;
};

=head2 do_get_upload( "name" )

B<NOTE> This garbles Hash::Multivalue.

=cut

sub do_get_upload {
	my ($self, $id) = @_;

	$self->{driver_upload} ||= $self->{driver}->uploads;
	my $up = $self->{driver_upload}{$id}; # TODO don't garble multivalues

	return $up ? { tempfile => $up->path, filename => $up->filename } : ();
};

=head2 do_get_header_in

=cut

sub do_get_header_in {
	my $self = shift;

	return $self->{driver}->headers;
};

=head2 do_reply( $status_line, \%headers, $content )

Send reply to client. Not to be used directly.

B<NOTE> This function just returns its input and has no side effect,
rather relying on PSGI calling conventions.

=cut

sub do_reply {
	my ($self, $status, $header, $content) = @_;

	my @header_array;
	foreach my $k (keys %$header) {
		if( ref $header->{$k} eq 'ARRAY' ) {
			# unfold key => [ xxx, yyy ... ] into list of pairs
			push @header_array, $k, $_
				for @{ $header->{$k} };
		} else {
			push @header_array, $k, $header->{$k};
		};
	};

	if (Encode::is_utf8($content)) {
		$content = encode_utf8($content);
	};

	# HACK - we're being returned by handler in MVC::Neaf itself in case of
	# PSGI being used.

	if ($self->{postponed}) {
		# Even hackier HACK. If we have a postponed action,
		# we must use PSGI functional interface to ensure
		# reply is sent to client BEFORE
		# postponed calls get executed.
		return sub {
			my $responder = shift;
			my $writer = $responder->( [ $status, \@header_array ] );
			$writer->write( $content );
			$writer->close;
			$self->execute_postponed;
		};
	};

	# Otherwise just return plain data.
	return [ $status, \@header_array, [ $content ]];
};

1;
