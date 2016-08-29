package MVC::Neaf::Request;

use strict;
use warnings;

=head1 NAME

MVC::Neaf::Request - CGI-based request class for Neaf.

=head1 METHODS

These methods are common for ALL Neaf::Request::* classes.

=cut

our $VERSION = 0.01;

=head2 new()

=cut

sub new {
	return bless {}, shift;
};

=head2 path()

Returns the path part of the uri.

=cut

sub path {
	return '/';
};

=head2 param($name, [$regex, $default])

Return param, if it passes regex check, default value (or '') otherwise.

=cut

sub param {
	my ($self, $name, $regex, $default) = @_;

	return $self->get_params->{ $name };
};

=head2 get_params()

Get all params as one hashref. Caching.

=cut

sub get_params {
	my $self = shift;

	return $self->{params} ||= do {
		my %hash;
		foreach (@ARGV) {
			m/^(\w+)=(.*)$/ or next;
			$hash{$1} = $2;
		};
		\%hash;
	};
};


my %status_line = (
	200 => 'OK',
	404 => 'Not Found',
	500 => 'Internal Server Error',
);

=head2 reply( $status, \%headers, $content )

Return data to requestor. Not to be used directly.

=cut

sub reply {
	my ($self, $status, $header, $content) = @_;

	my $line = $status_line{$status} || 'Teapot';

	print "HTTP/1.1 $status $line\n";
	foreach (keys %$header) {
		print "$_: $header->{$_}\n";
	};
	print "\n";
	print $content;
};

1;
