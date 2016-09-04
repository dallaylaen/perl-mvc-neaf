package MVC::Neaf::View::JS;

use strict;
use warnings;

our $VERSION = 0.0401;

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

my $codec = JSON::XS->new->allow_blessed->convert_blessed;
my $jsonp_re = qr/^(?:[A-Z_a-z][A-Z_a-z\d]*)(?:\.(?:[A-Z_a-z][A-Z_a-z\d]*))*$/;

=head2 show( \%data )

Returns a scalar with JSON-encoded data.

=cut

sub show {
    my ($self, $data) = @_;

    my $callback = $data->{-callback};
    my $type = $data->{-type};

    # TODO sanitize data in a more efficient way
    my %copy;
    foreach (keys %$data) {
        /^-/ or $copy{$_} = $data->{$_};
    };

    my $content = $codec->encode( \%copy );
    return $callback && $callback =~ $jsonp_re
        ? ("$callback($content);", "application/json; charset=utf-8")
        : ($content, "application/javascript; charset=utf-8");
};

1;
