package MVC::Neaf;

use 5.006;
use strict;
use warnings;

=head1 NAME

MVC::Neaf - Not Even A Framework for very simple web apps.

=head1 OVERVIEW

Neaf stands for Not Even An (MVC) Framework.

It is made for lazy people without an IDE.

The Model is assumed to be just a regular Perl module,
no restrictions are put on it.

The Controller is reduced to just one function which receives a Request object
and returns a \\%hashref with a mix
of actual data and minus-prefixed control parameters.

The View is expected to have one method, C<show>, receiving such hash
and returning scalar of rendered context.

The principals of Neaf are as follows:

=over

=item * Start out simple, then scale up.

=item * Already on Perl, needn't more magic.

=item * Everything can be configured, nothing needs to be.

=item * It's not software unless you can run it from command line.

=back

=head1 SYNOPSIS

    use MVC::Neaf;

	MVC::Neaf->route( "/app" => sub {
		return { ... };
	});
	MVC::Neaf->run;

=head1 METHODS

=cut

our $VERSION = 0.0107;

use MVC::Neaf::Request;

=head2 route( path => CODEREF, %options )

Creates a new route in the application.

=cut

my %route;
my $route_re;
sub route {
	my ($class, $path, $sub) = @_;

	# Sanitize path so that we have exactly one leading slash
	# root becomes nothing (which is OK with us).
	$path =~ s#^/*#/#;
	$path =~ s#/+$##;

	$route_re = undef;
	$route{ $path }{code} = $sub;
};

=head2 run()

Run the applicaton.

Returns a coderef under PSGI.

=cut

sub run {
	my $class = shift;
	# TODO Detect psgi/apache

	$route_re ||= $class->_make_route_re( \%route );

	if (caller eq 'main') {
		require MVC::Neaf::Request::CGI;
		my $req = MVC::Neaf::Request::CGI->new;
		$class->handle_request( $req );
	} else {
		# PSGI
		require MVC::Neaf::Request::PSGI;
		return sub {
			my $env = shift;
			my $req = MVC::Neaf::Request::PSGI->new( env => $env );
			return $class->handle_request( $req );
		};
	};
};

sub _make_route_re {
	my ($class, $hash) = @_;

	my $re = join "|", map { quotemeta } reverse sort keys %$hash;
	return qr{^($re)(?:[?/]|$)};
};

# The CORE

=head2 handle_request( MVC::Neaf::request->new )

This is the CORE of this module. Should not be called directly.

=cut

my %seen_view;
sub handle_request {
	my ($self, $req) = @_;

	my $data = eval {
		$req->path =~ $route_re || die '404\n';
		return $route{$1}{code}->($req);
	};

	if ($data) {
		$data->{-status} ||= 200;
	} else {
		$data = _error_to_reply( $@ );
	};

    # Render content if needed. This may alter type, so
    # produce headers later.
    my $content;
    if (defined $data->{-content}) {
        $content = $data->{-content};
        $data->{-type} ||= $content =~ /^.{0,512}[^\s\x20-\x7F]/
            ? 'text/plain' : 'application/octet-stream';
    } else {
		my $view = $data->{-view} || 'TT'; # TODO route defaults, global default
		$view = $seen_view{$view} ||= $self->load_view( $view );
        ($content, my $type) = $view->show( $data );
        $data->{-type} ||= $type || 'text/html';
    };

    # Handle headers
	my $headers = $self->make_headers( $data );
	$headers->{'Set-Cookie'} = $req->format_cookies;

	# This "return" is mostly for PSGI
	return $req->reply( _status_line($data->{-status}), $headers, $content );
};

our %status_table = (
    100 => "Continue",
    101 => "Switching Protocols",
    102 => "Processing",
    200 => "OK",
    201 => "Created",
    202 => "Accepted",
    203 => "Non-Authoritative Information",
    204 => "No Content",
    205 => "Reset Content",
    206 => "Partial Content",
    207 => "Multi-Status",
    208 => "Already Reported",
    226 => "IM Used",
    300 => "Multiple Choices",
    301 => "Moved Permanently",
    302 => "Found",
    303 => "See Other",
    304 => "Not Modified",
    305 => "Use Proxy",
    306 => "Switch Proxy",
    307 => "Temporary Redirect",
    308 => "Permanent Redirect",
    404 => "error on German Wikipedia",
    400 => "Bad Request",
    401 => "Unauthorized",
    402 => "Payment Required",
    403 => "Forbidden",
    404 => "Not Found",
    405 => "Method Not Allowed",
    406 => "Not Acceptable",
    407 => "Proxy Authentication Required",
    408 => "Request Timeout",
    409 => "Conflict",
    410 => "Gone",
    411 => "Length Required",
    412 => "Precondition Failed",
    413 => "Payload Too Large",
    414 => "URI Too Long",
    415 => "Unsupported Media Type",
    416 => "Range Not Satisfiable",
    417 => "Expectation Failed",
    418 => "I'm a teapot",
    421 => "Misdirected Request",
    422 => "Unprocessable Entity",
    423 => "Locked",
    424 => "Failed Dependency",
    426 => "Upgrade Required",
    428 => "Precondition Required",
    429 => "Too Many Requests",
    431 => "Request Header Fields Too Large",
    451 => "Unavailable For Legal Reasons",
    500 => "Internal Server Error",
    501 => "Not Implemented",
    502 => "Bad Gateway",
    503 => "Service Unavailable",
    504 => "Gateway Timeout",
    505 => "HTTP Version Not Supported",
    506 => "Variant Also Negotiates",
    507 => "Insufficient Storage",
    508 => "Loop Detected",
    510 => "Not Extended",
    511 => "Network Authentication Required",
);

sub _status_line {
	my $st = shift;
	my $status_line = $status_table{ $st };
	return defined $status_line ? "$st $status_line" : $st;
};

sub _error_to_reply {
	my $err = shift;

	if (ref $err eq 'HASH') {
		# TODO use own excp class
		$err->{-status} ||= 500;
		return $err;
	} else {
		my $status = $err =~ /^(\d\d\d)/ ? $1 : 500;
		warn "ERROR: $err" unless $1;

		return {
			-status     => $status,
			-type       => 'text/plain',
			-view       => 'TT',
			-template   => \"Error $status",
		};
	};
};

=head2 make_headers( $data )

Extract header data from application reply.

=cut

sub make_headers {
	my ($self, $data) = @_;

	my %head;
	$head{'Content-Type'} = $data->{-type} || "text/html";
	$head{'Location'} = $data->{-location}
		if $data->{-location};

	return \%head;
};

=head2 load_view( $view_name )

Load a view module by name.

=cut

my %known_view = (
	TT => 'MVC::Neaf::View::TT',
	JS => 'MVC::Neaf::View::JS',
);
sub load_view {
	my ($self, $view, $module) = @_;

	$module ||= $known_view{ $view } || $view;
	eval "require $module" ## no critic
		unless ref $module;

	die "Failed to load view $view: $@"
		if $@;

	$seen_view{$view} = $module;

	return $module;
};

=head1 AUTHOR

Konstantin S. Uvarin, C<< <khedin at gmail.com> >>

=head1 BUGS

Lots of them, this is ALPHA software.

Please report any bugs or feature requests to C<bug-mvc-neaf at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=MVC-Neaf>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc MVC::Neaf


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=MVC-Neaf>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/MVC-Neaf>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/MVC-Neaf>

=item * Search CPAN

L<http://search.cpan.org/dist/MVC-Neaf/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2016 Konstantin S. Uvarin.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of MVC::Neaf
