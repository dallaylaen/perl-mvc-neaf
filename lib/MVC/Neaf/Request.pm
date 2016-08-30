package MVC::Neaf::Request;

use strict;
use warnings;

=head1 NAME

MVC::Neaf::Request - Base request class for Neaf.

=head1 METHODS

These methods are common for ALL Neaf::Request::* classes.

=cut

our $VERSION = 0.0102;
use Carp;

=head2 new( %args )

For now, just swallows whatever given to it.

=cut

sub new {
	my ($class, %args) = @_;
	return bless \%args, $class;
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

=head2 get_path

Stub.

=cut

sub get_path {
	croak __PACKAGE__."::get_path() unimplemented";
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

=head2 get_params()


=cut

sub get_params {
	my $self = shift;

	croak __PACKAGE__."::get_params() unimplemented in base class";
};


=head2 reply( $status, \%headers, $content )

Return data to requestor. Not to be used directly.

=cut

sub reply {
	my ($self, $status, $header, $content) = @_;

	croak __PACKAGE__."::reply() unimplemented in base class";
};

1;
