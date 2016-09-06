package MVC::Neaf::View::TT;

use 5.006;
use strict;
use warnings;

our $VERSION = 0.06;

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

use parent qw(MVC::Neaf::View);

=head2 new( %options )



=cut

sub new {
    my ($class, %opt) = @_;

    # TODO some options for template, eh?
    $opt{engine} ||= Template->new;

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
    return ('', "text/plain")
        unless $template;

    my $out;
    $self->{engine}->process( $template, $data, \$out )
        or croak $self->{engine}->error;

    return ($out, "text/html");
};

=head1 SEE ALSO

L<Template> - the template toolkit used as backend.

=cut

1;
