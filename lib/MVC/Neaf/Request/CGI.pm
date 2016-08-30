package MVC::Neaf::Request::CGI;

use strict;
use warnings;

our $VERSION = 0.01;
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
	return \%args, $class;
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
	foreach (keys %$header) {
		print "$_: $header->{$_}\n";
	};
	print "\n";
	print $content;
};

1;
