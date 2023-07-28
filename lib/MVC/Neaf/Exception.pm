package MVC::Neaf::Exception;

use strict;
use warnings;
our $VERSION = '0.29';

=head1 NAME

MVC::Neaf::Exception - Exception class for Not Even A Framework.

=head1 DESCRIPTION

Currently internal signalling or L<MVC::Neaf> is based on the exception
mechanism. To avoid collisions with user's exceptions or Perl errors,
these internal exceptions are blessed into this class.

Please see the neaf_err() function in L<MVC::Neaf>.

By convention, C<die nnn> and C<die MVC::Neaf::Exception-E<gt>new( nnn )>
will be treated exactly the same by Neaf.

B<CAUTION.> This file is mostly used internally by Neaf
and may change with little to no warning.
Please file a bug/feature request demanding a more stable interface
if you plan to rely on it.

B<CAVEAT EMPTOR>.

=cut

use Scalar::Util qw(blessed);
use Carp;
use overload '""' => "as_string";

use MVC::Neaf::Util qw(bare_html_escape);

=head1 METHODS

=head2 new( $@ || 500, %options )

=head2 new( %options )

Returns a new exception object.

%options may include any keys as well as some Neaf-like control keys:

=over

=item * -status - alias for first argument.
If starts with 3 digits, will result in a "http error page" exception,
otherwise is reset to 500 and reason is updated.

=item * -reason - details about what happened

=item * -headers - array or hash of headers, just like that of a normal reply.

=item * -location - indicates a redirection

=item * -sudden - this was not an expected error (die 404 or redirect)
This will automatically turn on if -status cannot be parsed.

=item * -file - where error happened

=item * -line - where error happened

=item * -nocaller - don't try to determine error origin via caller

=back

=cut

sub new {
    my $class = shift;
    if (@_ % 2) {
        my $err = shift;
        push @_, -status => $err;
    };
    my %opt = @_;

    # TODO 0.30 bad rex will catch garbage if under 'C:\Program files'
    ($opt{-status} || '')
        =~ qr{^(?:(\d\d\d)\s*)?(.*?)(?:\s+at (\S+) line (\d+)\.?)?$}s
            or die "NEAF: Bug: Regex failed unexpectedly for q{$opt{-status}}";

    $opt{-status}   = $1 || 500;
    $opt{-reason} ||= $2 || $1 || 'unknown error';
    $opt{-sudden} ||= !$1;
    my @caller = $opt{-nocaller} ? () : (caller(0));
    $opt{-file}   ||= $3 || $caller[1];
    $opt{-line}   ||= $4 || $caller[2];

    return bless \%opt, $class;
};

=head2 status()

Return error code.

=cut

sub status {
    my $self = shift;
    return $self->{-status};
};

=head2 is_sudden()

Tells whether error was unexpected.

B<EXPERIMENTAL>. Name and meaning subject to change.

=cut

sub is_sudden {
    my $self = shift;
    return $self->{-sudden} ? 1 : 0;
};

=head2 as_string()

Stringify.

Result will start with C<MVC::Neaf:> if error was generated via
C<die 404> or a redirect.

Otherwise it would look similar to the original -status.

=cut

sub as_string {
    my $self = shift;

    return ($self->{-sudden} ? '' : "MVC::Neaf: ")
        .($self->{-location} ? "See $self->{-location}: " : '')
        . $self->reason;
};

=head2 make_reply( $request )

Returns a refault error HTML page.

The default page is guaranteen to contain
the status as its one and only C<< <span> >> element,
the unique request-id as one and only C<< <b> >> element,
and the location (if any) as its one and only C<< <i> >> element.

This page used to be a JSON but it turned out hard to debug
when dealing with javascript.

=cut

sub make_reply {
    my ($self, $req) = @_;

    my $code = $self->{-status};
    my $redirect = '';
    my $request_id = $req->id;
    my @headers = @{ $self->{-headers} || [] };
    if (my $where = $self->{-location}) {
        unshift @headers, Location => $where;
        $where = bare_html_escape( $where );
        $redirect = qq{<p>See <a href="$where"><i>$where</i></a></p>};
    };

    # An in-place template to avoid rendering
    # don't worry, be stupid!
    my $content = qq{<html>
<head>
    <title>Error $code</title>
</head>
<body>
    <h1>Error <span>$code</span></h1>
    <p>Request-id:<b>$request_id</b></p>
    $redirect
    <hr></hr>
    <small>Powered by <a href="https://metacpan.org/pod/MVC::Neaf">Not even a framework<a/>.</small>
</body>
</html>
};

    return {
        -status   => $self->{-status},
        -content  => $content,
        -type     => 'text/html; charset=utf8',
        -headers  => \@headers,
    };
};

=head2 reason()

Returns error message that was expected to cause the error.

=cut

sub reason {
    my $self = shift;

    return ($self->{-reason} || "Unknown error") . $self->file_and_line;
};

=head2 file_and_line

Return " at /foo/bar line 42" suffix, if both file and line are available.
Empty string otherwise.

=cut

sub file_and_line {
    my $self = shift;
    return ($self->{-file} && $self->{-line})
        ? " at $self->{-file} line $self->{-line}"
        : ''
};

=head2 TO_JSON()

Converts exception to JSON, so that it doesn't frighten View::JS.

=cut

sub TO_JSON {
    my $self = shift;
    return { %$self };
};

=head1 LICENSE AND COPYRIGHT

This module is part of L<MVC::Neaf> suite.

Copyright 2016-2023 Konstantin S. Uvarin C<khedin@cpan.org>.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.

=cut

1;
