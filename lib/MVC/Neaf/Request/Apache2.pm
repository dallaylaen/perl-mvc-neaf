package MVC::Neaf::Request::Apache2;

use strict;
use warnings;

our $VERSION = 0.03;

=head1 NAME

MVC::Neaf::Request::Apache - Apache2 (mod_perl) driver for Not Even A Framework.

=head1 METHODS

=cut

use URI::Escape;

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Request;
use Apache2::Upload;
use Apache2::Const -compile => 'OK';

use MVC::Neaf;
use parent qw(MVC::Neaf::Request);

=head2 do_get_method()

=cut

sub do_get_method {
	my $self = shift;

	return $self->{driver_raw}->method;
};

=head2 do_get_path()

=cut

sub do_get_path {
	my $self = shift;

	return $self->{driver_raw}->uri;
};

=head2 do_get_params()

=cut

sub do_get_params {
	my $self = shift;

	my %hash;
	my $r = $self->{driver};
	$hash{$_} = $r->param($_) for $r->param;

	return \%hash;
};

=head2 do_get_cookies()

=cut

sub do_get_cookies {
	my $self = shift;

	my %cook;
	foreach ($self->{driver_out}->headers_in->get("Cookie")) {
		/^(\S+)=(\S*)/ or next;
		$cook{ uri_unescape($1) } = uri_unescape( $2 );
	};

	return \%cook;
};

=head2 do_get_upload( "name" )

Convert apache upload object into MCV::Neaf::Upload.

=cut

sub do_get_upload {
	my ($self, $name) = @_;

	my $r = $self->{driver};
	my $upload = $r->upload($name);

	return $upload ? {
		handle => $upload->fh,
		tempfile => $upload->tempname,
		filename => $upload->filename,
	} : ();
};

=head2 do_get_referer() - unlike others, this won't die if unimplemented

=cut

sub do_get_referer {
	my $self = shift;

	return scalar $self->{driver_raw}->headers_in->get( "Referer" );
};

=head2 do_reply( $status, \%headers, $content )

=cut

sub do_reply {
	my ($self, $status, $header, $content) = @_;

	my $r = $self->{driver_raw};

	$r->status( $status );
	$r->content_type( delete $header->{'Content-Type'} );

	my $head = $r->headers_out;
	foreach my $name (keys %$header) {
		my $val = $header->{$name};
		$val = [ $val ]
			if (ref $val ne 'ARRAY');
		$head->add( $name, $_ ) for @$val;
	};

	$r->print( $content );
};


=head2 handler( $apache_request )

A valid Apache2/mod_perl handler.

This invokes MCV::Neaf->handle_request, so that the following works:

	LoadModule perl_module        modules/mod_perl.so
		PerlSwitches -I[% YOUR_LIB_DIRECTORY %]
	LoadModule apreq_module       [% modules %]/mod_apreq2.so

	# later...
	PerlModule MVC::Neaf::Request::Apache2
	PerlPostConfigRequire [% YOUR_APPLICATION %]
	<Location /[% SOME_URL_PREFIX %]>
		SetHandler perl-script
		PerlResponseHandler MVC::Neaf::Request::Apache2
	</Location>

Unfortunately, libapreq (in addition to mod_perl) is required currently.

=cut

sub handler : method {
	my ($class, $r) = @_;

	my $self = $class->new(
		driver_raw => $r,
		driver => Apache2::Request->new($r),
	);
	my $reply = MVC::Neaf->handle_request( $self );

	return Apache2::Const::OK;
};

1;
