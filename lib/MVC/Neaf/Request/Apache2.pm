package MVC::Neaf::Request::Apache2;

use strict;
use warnings;

our $VERSION = 0.02;

=head1 NAME

MVC::Neaf::Request::Apache - Apache2 (mod_perl) driver for Not Even A Framework.

=head1 METHODS

=cut

use URI::Escape;
use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Const -compile => 'OK';

use MVC::Neaf;
use parent qw(MVC::Neaf::Request);

=head2 do_get_method()

=cut

sub do_get_method {
	my $self = shift;

	return $self->{driver}->method;
};

=head2 do_get_path()

=cut

sub do_get_path {
	my $self = shift;

	return $self->{driver}->uri;
};

=head2 do_get_params()

=cut

sub do_get_params {
	my $self = shift;

	if ($self->method ne 'GET' and $self->method ne 'HEAD') {
		 die "unimplemented yet";
		# TODO implement post or find who did it
	};

	my $str = $self->{driver}->unparsed_uri;
	$str =~ s#^.*?\?## or return {};

	my %hash;
	foreach (split /&/, $str) {
		/^(\S+?)=(\S+)$/ or next;
		$hash{ uri_unescape($1) } = uri_unescape( $2 );
	};

	return \%hash;
};

=head2 do_get_cookies()

=cut

sub do_get_cookies {
	my $self = shift;

	my %cook;
	foreach ($self->{driver}->headers_in->get("Cookie")) {
		/^(\S+)=(\S*)/ or next;
		$cook{ uri_unescape($1) } = uri_unescape( $2 );
	};

	return \%cook;
};

=head2 do_get_upload()

=cut

# TODO I wanna die rigth here...

=head2 do_get_referer() - unlike others, this won't die if unimplemented

=cut

sub do_get_referer {
	my $self = shift;

	return scalar $self->{driver}->headers_in->get( "Referer" );
};

=head2 do_reply( $status, \%headers, $content )

=cut

sub do_reply {
	my ($self, $status, $header, $content) = @_;

	my $r = $self->{driver};

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


=head2 handler



=cut

sub handler : method {
	my ($class, $r) = @_;

	my $self = $class->new( driver => $r );
	my $reply = MVC::Neaf->handle_request( $self );

	return Apache2::Const::OK;
};

1;
