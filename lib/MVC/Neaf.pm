package MVC::Neaf;

use 5.006;
use strict;
use warnings;

our $VERSION = 0.0207;

=head1 NAME

MVC::Neaf - Not Even A Framework for very simple web apps.

=head1 OVERVIEW

Neaf [ni:f] stands for Not Even An (MVC) Framework.

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

use Scalar::Util qw(blessed);

use MVC::Neaf::Request;

our $force_view;
sub import {
	my ($class, %args) = @_;

	$args{view} and $force_view = $args{view};
};

=head2 route( path => CODEREF, %options )

Creates a new route in the application.

=cut

my $pre_route;
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
	return $class;
};

=head2 run()

Run the applicaton.

Returns a coderef under PSGI.

=cut

sub run {
	my $class = shift;
	# TODO Better detection still wanted

	$route_re ||= $class->_make_route_re( \%route );

	if (defined wantarray) {
		# The run method is being called in non-void context
		# This is the case for PSGI, but not CGI (where it's just
		# the last statement in the script).

		# PSGI
		require MVC::Neaf::Request::PSGI;
		return sub {
			my $env = shift;
			my $req = MVC::Neaf::Request::PSGI->new( env => $env );
			return $class->handle_request( $req );
		};
	} else {
		# void context - CGI called.
		require MVC::Neaf::Request::CGI;
		my $req = MVC::Neaf::Request::CGI->new;
		$class->handle_request( $req );
	};
};

sub _make_route_re {
	my ($class, $hash) = @_;

	my $re = join "|", map { quotemeta } reverse sort keys %$hash;
	return qr{^($re)(?:[?/]|$)};
};

=head2 pre_route( sub { ... } )

Mangle request before serving it.
E.g. canonize uri or read session cookie.

If the sub returns a MVC::Neaf::Request object in scalar context,
it is considered to replace the original one.
It looks like it's hard to return an unrelated Request by chance,
but beware!

=cut

sub pre_route {
	my ($self, $code) = @_;

	$pre_route = $code;
};

# The CORE

=head2 handle_request( MVC::Neaf::request->new )

This is the CORE of this module.
Should not be called directly - use run() instead.

=cut

my %seen_view;
sub handle_request {
	my ($self, $req) = @_;

	my $data = eval {
		# First, try running the pre-routing callback.
		if ($pre_route) {
			my $new_req = $pre_route->( $req );
			blessed $new_req and $new_req->isa("MVC::Neaf::Request")
				and $req = $new_req;
		};

		# Run the controller!
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
		# TODO route defaults, global default
		# TODO eval template errors
		my $view = $force_view || $data->{-view} || 'TT';
		$view = $seen_view{$view} ||= $self->load_view( $view );
        ($content, my $type) = $view->show( $data );
        $data->{-type} ||= $type || 'text/html';
    };

    # Handle headers
	my $headers = $self->make_headers( $data );
	$headers->{'Set-Cookie'} = $req->format_cookies;

	# This "return" is mostly for PSGI
	return $req->do_reply( $data->{-status}, $headers, $content );
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
	$head{'Content-Type'} =~ m#^text/[-\w]+$#
		and $head{'Content-Type'} .= "; charset=utf-8";

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
