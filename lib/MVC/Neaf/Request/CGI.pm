package MVC::Neaf::Request::CGI;

use strict;
use warnings;

our $VERSION = 0.0403;
use Carp;
use Encode;
use HTTP::Headers;

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

=head2 do_get_client_ip()

=cut

sub do_get_client_ip {
	my $self = shift;

	return $self->{driver}->remote_addr;
};

=head2 do_get_method()

Return GET/POST.

=cut

sub do_get_method {
	my $self = shift;
	return $self->{driver}->request_method;
};

=head2 do_get_http_version

HTTP/1.0 or HTTP/1.1

B<NOTE> This currently returns based on the presence of Host header,
which is a HACK. Haven't found a better way yet...

=cut

sub do_get_http_version {
	my $req = shift;

	return $req->header_in("host") ? "1.1" : "1.0";
};

=head2 do_get_scheme

Returns http or https.

=cut

sub do_get_scheme {
	my $self = shift;
	my @arr = $self->{driver}->https;
	return @arr ? "https" : "http";
};

=head2 do_get_hostname

Returns server hostname.

=cut

sub do_get_hostname {
	my $self = shift;
	return $self->{driver}->server_name;
};

=head2 do_get_port

Returns server port.

=cut

sub do_get_port {
	my $self = shift;
	return $self->{driver}->server_port;
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

	return $self->{driver}->url(-absolute => 1, -path => 1);
};

=head2 do_get_upload( "name" )

=cut

sub do_get_upload {
	my ($self, $id) = @_;

	my $filename = $self->{driver}->param($id);
	my $handle   = $self->{driver}->upload($id);

	return $handle ? { handle => $handle, filename => $filename } : ();
};

=head2 do_get_header_in

=cut

sub do_get_header_in {
	my $self = shift;

	my $head = HTTP::Headers->new;
	foreach ($self->{driver}->http) {
		$_ = lc $_;
		s/-/_/g;
		s/^http_//;
		$head->header( $_ => [ split /, /, $self->{driver}->http( $_ ) ] );
	};

	return $head;
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
