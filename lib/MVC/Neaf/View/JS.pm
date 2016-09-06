package MVC::Neaf::View::JS;

use strict;
use warnings;

our $VERSION = 0.06;

=head1 NAME

MVC::Neaf::View::JS - JSON-base view for Not Even A Framework.

=head1 SYNOPSIS

    return {
        # your data ...
        -view => 'JS',
        -callback => 'my.jsonp.callback', # this is optional
    }

Will result in your application returning raw data in JSON/JSONP format
instead or rendering a template.

=head1 METHODS

=cut

use JSON::XS;

use parent qw(MVC::Neaf::View);

my $codec = JSON::XS->new->allow_blessed->convert_blessed;
my $jsonp_re = qr/^(?:[A-Z_a-z][A-Z_a-z\d]*)(?:\.(?:[A-Z_a-z][A-Z_a-z\d]*))*$/;

=head2 new( %options )



=cut

=head2 render( \%data )

Returns a scalar with JSON-encoded data.

=cut

sub render {
    my ($self, $data) = @_;

    my $callback = $data->{-callback};
    my $type = $data->{-type};

    # TODO sanitize data in a more efficient way
    my %copy;
    foreach (keys %$data) {
        /^-/ and next;
        ref $data->{$_} eq 'CODE' and next;
        $copy{$_} = $data->{$_};
    };

    my $content = $codec->encode( \%copy );
    return $callback && $callback =~ $jsonp_re
        ? ("$callback($content);", "application/javascript; charset=utf-8")
        : ($content, "application/json; charset=utf-8");
};

1;
