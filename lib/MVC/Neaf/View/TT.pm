package MVC::Neaf::View::TT;

use 5.006;
use strict;
use warnings;

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

our $VERSION = 0.02;

use Carp;
use Template;

=head2 show( \%data )

Returns processed data.

=cut

sub show {
	my ($self, $data) = @_;

	my $template = $data->{-template};
	return '' unless $template;

	my $out;
	Template->new->process( $template, $data, \$out );

	return $out;
};

=head1 SEE ALSO

L<Template> - the template toolkit used as backend.

=cut

1;
