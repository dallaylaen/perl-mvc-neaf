package MVC::Neaf;

use 5.006;
use strict;
use warnings;

=head1 NAME

MVC::Neaf - Not Even A Framework for very simple web apps.

=cut


=head1 SYNOPSIS

    use MVC::Neaf;

	MVC::Neaf->route( "/app" => sub {
		return { ... };
	});
	MVC::Neaf->run;

=head1 METHODS

=cut

our $VERSION = 0.0101;

use MVC::Neaf::Request;

=head2 route( path => CODEREF, %options )

Creates a new route in the application.

=cut

my %route;
my $route_re;
sub route {
	my ($class, $path, $sub) = @_;

	$route_re = undef;
	$route{ $path }{code} = $sub;
};

=head2 run()

Run the applicaton.

Returns a coderef under PSGI.

=cut

sub run {
	my $class = shift;
	# TODO if under psgi/apache

	$route_re ||= $class->_make_route_re( \%route );
	my $req = MVC::Neaf::Request->new;
	$class->handle_request( $req );
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
	my ($class, $req) = @_;

	my $data = eval {
		$req->path =~ $route_re || die '404\n';
		return $route{$1}{code}->($req);
	};

	if (!$data) {
		# TODO try to handle error
		my $err = $@;

		my $status = $err =~ /^(\d\d\d)/ || 500;
		$data = {
			-status     => $status,
			-type       => 'text/plain',
			-view       => 'TT',
			-template   => \"Error $status",
		};
	} else {
		$data->{-status} ||= 200;
	};

	my $view = $data->{-view} || 'TT'; # TODO route defaults, global default

	$data->{-type} ||= 'text/html';
	$view = $seen_view{$view} ||= $class->load_view( $view );

	my $content = $view->show( $data );
	my $headers = {
		'Content-Type' => $data->{-type},
	};

	$req->reply( $data->{-status}, $headers, $content )
};

=head2 load_view( $view_name )

Load a view module by name.

=cut

my %known_view = (
	TT => 'MVC::Neaf::View::TT',
);
sub load_view {
	my ($self, $view) = @_;

	my $class = $known_view{ $view } || $view;
	eval "require $class"; ## no critic

	die "Failed to load view $view: $@"
		if $@;
	return $class;
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
