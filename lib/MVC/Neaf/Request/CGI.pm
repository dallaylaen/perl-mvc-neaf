package MVC::Neaf::Request::CGI;

use strict;
use warnings;

our $VERSION = 0.0101;
use Carp;

use base qw(MVC::Neaf::Request);

my $cgi;
foreach (qw(CGI::Minimal CGI)) {
	eval "require $_; 1" or next; ##no critic
	$cgi = $_;
	last;
};
$cgi or croak "No suitable CGI module found";

=head2 new()

=cut

sub new {
	my ($class, %args) = @_;

	$args{driver} ||= $cgi->new;
	return bless \%args, $class;
};

=head2 get_params

=cut

sub get_params {
	my $self = shift;

	my $q = $self->{driver};
	my %hash;
	foreach ($q->param) {
		$hash{$_} = $q->param($_);
	};
	return \%hash;
};

=head2 get_path

=cut

sub get_path {
	my $self = shift;

	return $self->{driver}->url(-absolute => 1);
};

=head2 reply

=cut

sub reply {
	my ($self, $status, $header, $content) = @_;

	print "Status: $status\n";
	foreach my $name (keys %$header) {
		my $value = $header->{$name};
		if (ref $value eq 'ARRAY') {
			print "$name: $_\n" for @$value;
		} else {
			print "$name: $value\n";
		};
	};
	print "\n";
	print $content;
};

=head2 do_get_cookies

=cut

sub do_get_cookies {
	my $self = shift;

	my @cook = $self->{driver}->cookie;
	my %ret;
	foreach (@cook) {
		$ret{$_} = $self->{driver}->cookie( $_ );
	};

	return \%ret;
};

1;
