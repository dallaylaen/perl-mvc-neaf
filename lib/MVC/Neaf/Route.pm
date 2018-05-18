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
use Encode;
use Scalar::Util qw(looks_like_number);
use URI::Escape qw(uri_unescape);

use parent qw(MVC::Neaf::Util::Base);
use MVC::Neaf::Util qw( canonize_path path_prefixes run_all run_all_nodie http_date );

our @CARP_NOT = qw(MVC::Neaf MVC::Neaf::Request);

=head2 new

Route has the following read-only attributes:

=over

=item * parent (required)

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

=item * where

=item * tentative

=item * override TODO

=item * hooks

=back

=cut

# Should just Moo here but we already have a BIG dependency footprint
my @ESSENTIAL = qw( parent method path code );
my @OPTIONAL  = qw(
    default cache_ttl
    path_info_regex param_regex hooks
    description public caller where tentative
    override
);
my %RO_FIELDS;
$RO_FIELDS{$_}++ for @ESSENTIAL, @OPTIONAL;
my $year = 365 * 24 * 60 * 60;

sub new {
    my ($class, %opt) = @_;

    # kill generated fields
    delete $opt{$_} for qw( lock );

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
    $opt{caller}  ||= [caller(0)]; # save file,line
    $opt{where}   ||= "at $opt{caller}[1] line $opt{caller}[2]";

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

=head2 is_locked

Check that route is locked.

=cut

sub is_locked {
    my $self = shift;
    return !!$self->{lock};
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

=head2 set_hooks(\%phases)

Install hooks. Currently no preprocessing is done.

=cut

sub set_hooks {
    my ($self, $hooks) = @_;

    # TODO 0.00 filter must be here
    $self->{hooks} = $hooks;
};

=head2 post_setup

Calculate hooks and path-based defaults.

Locks route, dies if already locked.

=cut

sub post_setup {
    my $self = shift;

    # LOCK PROFILE
    confess "Attempt to repeat route setup. MVC::Neaf broken, please file a bug"
        if $self->is_locked;

    my $neaf = $self->parent;
    # CALCULATE DEFAULTS
    # merge data sources, longer paths first
    my @sources = map { $neaf->{path_defaults}{$_} }
        reverse path_prefixes( $self->path );
    $self->append_defaults( @sources );

    # CALCULATE HOOKS
    # select ALL hooks prepared for upper paths
    my $hook_tree = $neaf->{hooks}{ $self->method };
    my @hook_by_path =
        map { $hook_tree->{$_} || () } path_prefixes( $self->path );

    # Merge callback stacks into one hash, in order
    # hook = {method}{path}{phase}[nnn] => { code => sub{}, ... }
    # We need to extract that sub {}
    # We do so in a rather clumsy way that would short cirtuit
    #     at all possibilities
    # Premature optimization FTW!
    my %phases;
    foreach my $hook_by_phase (@hook_by_path) {
        foreach my $phase ( keys %$hook_by_phase ) {
            my $hook_list = $hook_by_phase->{$phase};
            foreach my $hook (@$hook_list) {
                # process excludes - if path starts with any, no go!
                grep { $self->path =~ m#^\Q$_\E(?:/|$)# }
                    @{ $hook->{exclude} }
                        and next;
                # TODO 0.90 filter out repetition
                push @{ $phases{$phase} }, $hook->{code};
                # TODO 0.30 also store hook info somewhere for better error logging
            };
        };
    };

    # the pre-reply, pre-cleanup should go in backward direction
    # those are for cleaning up stuff
    $phases{$_} and @{ $phases{$_} } = reverse @{ $phases{$_} }
        for qw(pre_cleanup pre_reply);

    $self->set_hooks( \%phases );
    $self->lock;

    return;
};

sub _handle_logic {
    my ($self, $req, $path, $path_info) = @_;

    $self->post_setup
        unless $self->{lock};

    # TODO 0.90 optimize this or do smth. Still MUST keep route_re a prefix tree
    if ($path_info =~ /%/) {
        $path_info = decode_utf8( uri_unescape( $path_info ) );
    };
    my @split = $path_info =~ $self->path_info_regex
        or die "404\n";
    $req->_import_route( $self, $path, $path_info, \@split );

    # execute hooks
    run_all( $self->{hooks}{pre_logic}, $req)
        if exists $self->{hooks}{pre_logic};

    # Run the controller!
    return $self->code->($req);
};

=head2 INTERNAL LOGIC

The following methods are part of NEAF's core and should not be called
unless you want something I<very> special.

=head2 dispatch_logic

    dispatch_logic( $req, $stem, $suffix )

May die. May spoil request.

Apply controller code to given request object, path stem, and path suffix.

Upon success, return a Neaf response hash (see L<MVC::Neaf/THE-RESPONSE>).

=cut

sub dispatch_logic {
    my ($self, $req, $stem, $suffix) = @_;

    $self->post_setup
        unless $self->{lock};

    # TODO 0.90 optimize this or do smth. Still MUST keep route_re a prefix tree
    if ($suffix =~ /%/) {
        $suffix = decode_utf8( uri_unescape( $suffix ) );
    };
    my @split = $suffix =~ $self->path_info_regex
        or die "404\n";
    $req->_import_route( $self, $stem, $suffix, \@split );

    # execute hooks
    run_all( $self->{hooks}{pre_logic}, $req)
        if exists $self->{hooks}{pre_logic};

    # Run the controller!
    my $reply = $self->code->($req);
#   TODO cannot write to request until hash type-checked
#    $req->_set_reply( $reply );
    $reply;
};

=head2 PROXY METHODS

The following methods are redirected as is to 'parent'
(presumably a L<MVC::Neaf> instance.

=over

=item * get_form

=item * get_view

=back

=cut

# Setup proxy methods
foreach (qw(get_form get_view)) {
    my $method = $_;
    use warnings FATAL=>qw(all);
    my $sub = sub { (shift)->parent->$method(@_) };
    no strict 'refs'; ## no critic
    *{$method} = $sub;
};

# Setup getters
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