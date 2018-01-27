package MVC::Neaf::Route;

use strict;
use warnings;

our $VERSION = 0.2203;

=head1 NAME

MVC::Neaf::Route - Route (path+method) class for Not Even A Framework

=head1 DESCRIPTION

This module contains information about a handler defined using
L<MVC::Neaf>: method, path, handling code, connected hooks, default values etc.

It is useless in and off itself.

=head1 METHODS

=cut

use Carp;
use Scalar::Util qw(looks_like_number);

use parent qw(MVC::Neaf::Util::Base);
use MVC::Neaf::Util qw(canonize_path);

our @CARP_NOT = qw(MVC::Neaf MVC::Neaf::Request);

=head2 new

Route has the following read-only attributes:

=over

=item * path (required)

=item * method (required)

=item * code (required)

=item * default

=item * cache_ttl

=item * path_info_regex

=item * param_regex

=item * description

=item * public

=item * caller

=item * tentative

=item * override TODO

=item * hooks

=back

=cut

# Should just Moo here but we already have a BIG dependency footprint
my @ESSENTIAL = qw(method path code);
my @OPTIONAL  = qw(
    default cache_ttl
    path_info_regex param_regex hooks
    description public caller tentative
    override
);
my %RO_FIELDS;
$RO_FIELDS{$_}++ for @ESSENTIAL, @OPTIONAL;
my $year = 365 * 24 * 60 * 60;

sub new {
    my ($class, %opt) = @_;

    # kill generated fields
    delete $opt{$_} for qw(lock where);

    my @missing = grep { !defined $opt{$_} } @ESSENTIAL;
    my @extra   = grep { !$RO_FIELDS{$_}   } keys %opt;

    $class->my_croak( "Required fields missing: @missing; unknown fields present: @extra" )
        if @extra + @missing;

    # Canonize args
    $opt{method} = uc $opt{method};
    $opt{default} ||= {};
    $opt{path}   = canonize_path($opt{path});
    $opt{public} = $opt{public} ? 1 : 0;

    # Check args
    $class->my_croak("'code' must be a subroutine, not ".(ref $opt{code}||'scalar'))
        unless UNIVERSAL::isa($opt{code}, 'CODE');
    $class->my_croak("'public' endpoint must have a 'description'")
        if $opt{public} and not $opt{description};
    $class->_croak( "'default' must be unblessed hash" )
        if ref $opt{default} ne 'HASH';
    $class->my_croak("'method' must be a plain scalar")
        unless $opt{method} =~ /^[A-Z0-9_]+$/;

    # Always have regex defined to simplify routing
    if (!UNIVERSAL::isa($opt{path_info_regex}, 'Regexp')) {
        $opt{path_info_regex} = (defined $opt{path_info_regex})
            ? qr#^$opt{path_info_regex}$#
            : qr#^$#;
    };

    # Just for information
    $opt{caller}    ||= [caller(0)]; # save file,line
    $opt{where}       = "at $opt{caller}[1] line $opt{caller}[2]";

    # preprocess regular expression for params
    if ( my $reg = $opt{param_regex} ) {
        my %real_reg;
        $class->_croak("param_regex must be a hash of regular expressions")
            if ref $reg ne 'HASH' or grep { !defined $reg->{$_} } keys %$reg;
        $real_reg{$_} = qr(^$reg->{$_}$)s
            for keys %$reg;
        $opt{param_regex} = \%real_reg;
    };

    if ( $opt{cache_ttl} ) {
        $class->_croak("cache_ttl must be a number")
            unless looks_like_number($opt{cache_ttl});
        # as required by RFC
        $opt{cache_ttl} = -100000 if $opt{cache_ttl} < 0;
        $opt{cache_ttl} = $year if $opt{cache_ttl} > $year;
        $opt{cache_ttl} = $opt{cache_ttl};
    };

    return bless \%opt, $class;
};

=head2 clone

Create a copy of existing route, possibly overriding some of the fields.

=cut

# TODO 0.30 -> Util::Base?
sub clone {
    my ($self, %override) = @_;

    return (ref $self)->new( %$self, %override );
};

=head2 lock()

Prohibit any further modifications to this route.

=cut

sub lock {
    my $self = shift;
    $self->{lock}++;
    return $self;
};

# TODO 0.30 -> Util::Base?
sub _can_modify {
    my $self = shift;
    return unless $self->{lock};
    # oops

    croak "Modification of locked ".(ref $self)." attempted";
};

=head2 append_defaults( \%hashref, \%hashref2 )

Add more default values.

=cut

sub append_defaults {
    my ($self, @hashes) = @_;

    $self->_can_modify;

    # merge hashes, older override newer
    my %data = map { %$_ } grep { defined $_ }
        ((reverse @hashes), $self->{default});

    # kill undefs
    defined $data{$_} or delete $data{$_}
        for keys %data;

    $self->{default} = \%data;
    return $self;
};

# TODO 0.30 Class::XSAccessors or smth
foreach (keys %RO_FIELDS) {
    my $method = $_;
    my $sub = sub { $_[0]->{$method} };
    no strict 'refs'; ## no critic
    *{$method} = $sub;
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
