package MVC::Neaf::View::TT;

use 5.006;
use strict;
use warnings;

our $VERSION = 0.1701;

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

sub new {
    my ($class, %opt) = @_;

    my %tt_opt;
    $tt_opt{$_} = delete $opt{$_}
        for grep { /^[A-Z]/ } keys %opt;
    $opt{engine} ||= Template->new (%tt_opt);

    return $class->SUPER::new(%opt);
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
        # TODO 0.20 just die here
        croak __PACKAGE__.": -template option is required"
            unless $self->{-transitional};

        require MVC::Neaf::View::JS;
        $self->{js_engine} ||= MVC::Neaf::View::JS->new;
        return $self->{js_engine}->render( $data );
    };

    carp "NEAF Default TT view is deprecated, use load_view() explicitly after v.0.20"
        if $self->{-transitional} and !$self->{already_warned}++;

    my $out;
    $self->{engine}->process( $template, $data, \$out )
        or croak $self->{engine}->error;

    return ($out, "text/html");
};

=head1 SEE ALSO

L<Template> - the template toolkit used as backend.

=cut

1;
