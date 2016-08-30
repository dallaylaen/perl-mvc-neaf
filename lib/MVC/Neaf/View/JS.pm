package MVC::Neaf::View::JS;

use strict;
use warnings;

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

our $VERSION = 0.01;
use JSON::XS;

my $codec = JSON::XS->new->allow_blessed->convert_blessed;

=head2 show( \%data )

Returns a scalar with JSON-encoded data.

=cut

sub show {
	my ($self, $data) = @_;

	my $callback = delete $data->{-callback};
	my $type = delete $data->{-type};

	# TODO sanitize data in a better way
	foreach (keys %$data) {
		/^-/ and delete $data->{$_};
	};

	my $content = $codec->encode( $data );
	return $callback ? "$callback($content);" : $content;
};

1;
