package MVC::Neaf::View::TT;

use 5.006;
use strict;
use warnings;

our $VERSION = 0.03;

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

=head2 show( \%data )

Returns processed data.

=cut

my $tt = Template->new;

sub show {
	my ($self, $data) = @_;

	my $template = $data->{-template};
	return '' unless $template;

	my $out;
	$tt->process( $template, $data, \$out )
		or die $tt->error;

	return ($out, "text/html");
};

=head1 SEE ALSO

L<Template> - the template toolkit used as backend.

=cut

1;
