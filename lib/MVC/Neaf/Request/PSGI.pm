package MVC::Neaf::Request::PSGI;

use strict;
use warnings;

=head1 NAME

MVC::Neaf::Request::PSGI - Not Even A Framework: PSGI driver.

=head1 METHODS

=cut

our $VERSION = 0.0102;
use URI::Escape qw(uri_unescape);
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

=head2 get_path()

Returns the path part of URI.

=cut

sub get_path {
	my $self = shift;

	my $path = $self->{env}{REQUEST_URI};

	$path =~ s#\?.*$##;
	$path =~ s#^/*#/#;

	return $path;
};

=head2 get_params()

Returns GET/POST parameters as a hash.

B<CAVEAT> Plack::Request's multivalue hash params are ignored for now.

=cut

sub get_params {
	my $self = shift;

	my %hash;
	foreach ( $self->{driver}->param ) {
		$hash{$_} = $self->{driver}->param( $_ );
	};

	return \%hash;
};

=head2 do_get_cookies

Use Plack::Request to fetch cookies.

=cut

sub do_get_cookies {
	my $self = shift;

	return $self->{driver}->cookies;
};

=head2 reply( $status_line, \%headers, $content )

Send reply to client. Not to be used directly.

B<NOTE> This function just returns its input and has no side effect,
rather relying on PSGI calling conventions.

=cut

sub reply {
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

	# HACK - we're being returned by handler in MVC::Neaf itself in case of
	# PSGI being used.
	return [ $status, \@header_array, [ $content ]];
};

1;
