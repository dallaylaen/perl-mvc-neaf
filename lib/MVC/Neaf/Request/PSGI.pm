package MVC::Neaf::Request::PSGI;

use strict;
use warnings;

our $VERSION = 0.0101;
use URI::Escape qw(uri_unescape);
use Plack::Request;

use parent qw(MVC::Neaf::Request);

=head2 get_path

=cut

sub get_path {
	my $self = shift;

	my $path = $self->{env}{REQUEST_URI};

	$path =~ s/\?.*$//;

	return $path;
};

=head2 get_params

=cut

sub get_params {
	my $self = shift;

	my $path = $self->{env}{REQUEST_URI};
	$path =~ /.*?\?(.*)/ or return {};
	my $raw = $1;

	my %hash;
	foreach (split /&/, $raw) {
		/^(.*?)=(.*)$/ or next;
		$hash{uri_unescape($1)} = uri_unescape($2);
	};

	return \%hash;
};

=head2 do_get_cookies

Use Plack::Request to fetch cookies.

=cut

sub do_get_cookies {
	my $self = shift;

	my $req = Plack::Request->new( $self->{env} );
	return $req->cookies;
};

=head2 reply

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

	# HACK - we're being returned by handler.
	return [ $status, \@header_array, [ $content ]];
};

1;
