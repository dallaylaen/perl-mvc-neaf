package MVC::Neaf::Util::Container;

use strict;
use warnings;
our $VERSION = 0.23;

=head1 NAME

MVC::Neaf::Util::Container - path & method based container for Not Even A Framework

=head1 DESCRIPTION

This is utility class.
Nothing to see here unless one intends to work on L<MVC::Neaf> itself.

This class can hold multiple entities addressed by paths and methods
and extract them in the needed order.

=head1 SYNOPSIS

    my $c = MVC::Neaf::Util::Container->new;

    $c->store( "foo", path => '/foo', method => 'GET' );
    $c->store( "bar", path => '/foo/bar', exclude => '/foo/bar/baz' );

    $c->fetch( path => "/foo", method => 'GET' ); # foo
    $c->fetch( path => "/foo/bar", method => 'GET' ); # foo bar
    $c->fetch( path => "/foo/bar", method => 'POST' );
            # qw(bar) - 'foo' limited to GET only
    $c->fetch( path => "/foo/bar/baz", method => 'GET' );
            # qw(foo) - 'bar' excluded

=head1 METHODS

=cut

use parent qw(MVC::Neaf::Util::Base);
use MVC::Neaf::Util qw( maybe_list canonize_path path_prefixes );

=head2 store

    store( $data, %spec )

Store $data in container. Spec may include:

=over

=item path - single path or list of paths, '/' assumed if none.

=item method - name of method or array of methods.
No restrictions assumed by default.

=item exclude - single path or list of paths. None by default.

=back

=cut

sub store {
    my ($self, $data, %opt) = @_;

    $opt{data} = $data;
    maybe_list( \$opt{path}, '' );
    if ($opt{method}) {
        my %allow;
        $allow{$_} = 1 for maybe_list( $opt{method} );
        $opt{method} = \%allow;
    };
    if ($opt{exclude}) {
        my $rex = join '|', map { quotemeta(canonize_path($_)) } maybe_list($opt{exclude} );
        $opt{exclude} = qr(^(?:$rex)(?:[/?]|$));
    };

    foreach my $path ( @{ maybe_list( $opt{path}, '' ) } ) {
        my $array = $self->{data}{canonize_path($path)} ||= [];
        push @$array, \%opt;
    };

    $self;
};

=head2 fetch

    fetch( %spec )

Return all matching previously stored objects,
from shorter to longer paths, in order of addition.

Spec may include:

=over

=item path - a single path to match against

=item method - method to match against

=back

=cut

sub fetch {
    my ($self, %opt) = @_;

    $opt{path} = canonize_path( $opt{path} || '' );

    my @ret;
    foreach my $path ( path_prefixes( $opt{path} || '' ) ) {
        my $list = $self->{data}{$path};
        next unless $list;
        foreach my $node( @$list ) {
            next if $node->{method} and not $node->{method}{ $opt{method} || '' };
            next if $node->{exclude} and $opt{path} =~ $node->{exclude};
            push @ret, $node->{data};
        };
    };

    return @ret;
};

=head1 LICENSE AND COPYRIGHT

This module is part of L<MVC::Neaf> suite.

Copyright 2016-2018 Konstantin S. Uvarin C<khedin@cpan.org>.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.

=cut

1;
