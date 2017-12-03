package MVC::Neaf::View::TT;

use 5.006;
use strict;
use warnings;

our $VERSION = 0.2004;

=head1 NAME

MVC::Neaf::View::TT - Template toolkit-based view module for Neaf.

=head1 SYNOPSYS

    # Somewhere in your app
    return {
        -view => 'TT',
        -template => 'foo.tt',
        title => 'Page title',
        ....
    };

=head1 METHODS

=cut

use Carp;
use Template;
use Template::Provider;

our @CARP_NOT = qw(MVC::Neaf::View MVC::Neaf MVC::Neaf::Request);

use parent qw(MVC::Neaf::View);

=head2 new( %options )

%options may include:

=over

=item * template - default template to use.

=item * preserve_dash - don't strip dashed options. Useful for debugging.

=back

Also any UPPERCASE OPTIONS will be forwarded to the backend
(i.e. Template object) w/o changes.

B<NOTE> No input checks are made whatsoever,
but this MAY change in the future.

=cut

my %new_opt;
$new_opt{$_}++ for qw( template preserve_dash engine preload );

my @opt_provider = qw(
    INCLUDE_PATH ABSOLUTE RELATIVE DEFAULT ENCODING CACHE_SIZE STAT_TTL
    COMPILE_EXT COMPILE_DIR TOLERANT PARSER DEBUG EVAL_PERL
);

sub new {
    my ($class, %opt) = @_;

    my %tt_opt;
    $tt_opt{$_} = delete $opt{$_}
        for grep { /^[A-Z]/ } keys %opt;
    my @extra = grep { !$new_opt{$_} } keys %opt;
    croak( "$class->new: Unknown options @extra" )
        if @extra;

    $opt{engine} ||= do {
        my %prov_opt;
        $tt_opt{INCLUDE_PATH} ||= [];
        $prov_opt{$_} = $tt_opt{$_}
            for @opt_provider;
        defined $prov_opt{$_} or delete $prov_opt{$_}
            for keys %prov_opt;

        my $prov = delete $tt_opt{LOAD_TEMPLATES} || [
            Template::Provider->new(\%prov_opt)
        ];
        $opt{engine_preload} = Template::Provider->new({
            %prov_opt,
            CACHE_SIZE => undef,
            STAT_TTL   => 4_000_000_000,
        });
        # shallow copy (not unshift) to avoid spoiling original values
        $prov = [ $opt{engine_preload}, @$prov ];

        Template->new (%tt_opt, LOAD_TEMPLATES => $prov);
    };

    my $pre = delete $opt{preload};
    my $self = $class->SUPER::new(%opt);
    if ( $pre ) {
        $self->preload( $_ => $pre->{$_} )
            for keys %$pre;
    };
    return $self;
};

=head2 render( \%data )

Returns a pair of values: ($content, $content_type).

Content-type defaults to text/html.

The template is determined from (1) -template in data (2) template in new().
If neither is present, empty string and "text/plain" are returned.

=cut

sub render {
    my ($self, $data) = @_;

    my $template = $data->{-template} || $self->{template};

    if (!defined $template) {
        croak __PACKAGE__.": -template option is required";
    };

    my $out;
    $self->{engine}->process( $template, $data, \$out )
        or $self->_croak( $self->{engine}->error );

    return wantarray ? ($out, "text/html") : $out;
};

=head2 preload ( "name", "[% in_memory_template %]" )

Compile given template and store it under given name for future use.

Returns self, dies on error.

=cut

sub preload {
    my ($self, $name, $raw_tpl) = @_;

    my $compiled = eval { $self->{engine}->template( \$raw_tpl ) }
        or $self->_croak( $@ );

    $self->{engine_preload}->store( $name, $compiled );

    return $self;
};

sub _croak {
    my ($self, @msg) = @_;

    my $where = [caller(1)]->[3];
    $where =~ s/.*:://;

    croak join "", (ref $self || $self), '->', $where, "(): ", @msg;
};

=head1 SEE ALSO

L<Template> - the template toolkit used as backend.

=cut

1;
