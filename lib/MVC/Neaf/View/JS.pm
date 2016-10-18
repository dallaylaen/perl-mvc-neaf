package MVC::Neaf::View::JS;

use strict;
use warnings;

our $VERSION = 0.1001;

=head1 NAME

MVC::Neaf::View::JS - JSON-base view for Not Even A Framework.

=head1 SYNOPSIS

    return {
        # your data ...
        -view => 'JS',
        -jsonp => 'my.jsonp.callback', # this is optional
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

%options may include:

=over

=item * preserve_dash - don't strip dashed options. Useful for debugging.

=back

B<NOTE> No input checks are made whatsoever,
but this MAY change in the future.

=cut

=head2 render( \%data )

Returns a scalar with JSON-encoded data.

=cut

sub render {
    my ($self, $data) = @_;

    my $callback = $data->{-jsonp};
    my $type = $data->{-type};

    # TODO sanitize data in a more efficient way
    my %copy;
    foreach (keys %$data) {
        !$self->{preserve_dash} and /^-/ and next;
        if (ref $data->{$_} eq 'CODE') {
            $copy{$_} = $self->{replace_code}
                if exists $self->{replace_code};
        } elsif (ref $data->{$_} eq 'SCALAR') {
            $copy{$_} = [ ${ $data->{$_} } ];
        } else {
            $copy{$_} = $data->{$_};
        };
    };

    my $content = $codec->encode( \%copy );
    return $callback && $callback =~ $jsonp_re
        ? ("$callback($content);", "application/javascript; charset=utf-8")
        : ($content, "application/json; charset=utf-8");
};

1;
