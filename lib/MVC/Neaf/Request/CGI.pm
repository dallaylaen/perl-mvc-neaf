package MVC::Neaf::Request::CGI;

use strict;
use warnings;

our $VERSION = 0.0202;
use Carp;
use Encode;

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

=head2 do_get_method()

Return GET/POST.

=cut

sub do_get_method {
	my $self = shift;
	return $self->{driver}->request_method;
};

=head2 do_get_params

=cut

sub do_get_params {
	my $self = shift;

	my $q = $self->{driver};
	my %hash;
	foreach ($q->param) {
		$hash{$_} = $q->param($_);
	};
	return \%hash;
};

=head2 do_get_path

=cut

sub do_get_path {
	my $self = shift;

	return $self->{driver}->url(-absolute => 1);
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

=head2 do_get_upload( "name" )

=cut

sub do_get_upload {
	my ($self, $id) = @_;

	my $filename = $self->{driver}->param($id);
	my $handle   = $self->{driver}->upload($id);

	return $handle ? { handle => $handle, filename => $filename } : ();
};

=head2 do_get_referer()

=cut

sub do_get_referer {
	my $self = shift;

	return $self->{driver}->referer;
};


=head2 do_reply

=cut

sub do_reply {
	my ($self, $status, $header, $content) = @_;

	if (Encode::is_utf8($content)) {
		$content = encode_utf8($content);
	};

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

1;
