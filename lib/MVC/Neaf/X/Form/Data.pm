package MVC::Neaf::X::Form::Data;

use strict;
use warnings;
our $VERSION = 0.1302;

=head1 NAME

MVC::Neaf::X::Form::Data - Form validation result object.

=head1 CAUTION

This module should be moved into a separate distribution or (ideally)
merged with an existing module with similar functionality.

Possible candidates include L<Validator::LIVR>, L<Data::FormValidator>,
L<Data::CGIForm>, and more.

=head1 DESCRIPTION

See L<MVC::Neaf::X::Form>.
This class is not expected to be created and used directly.

=head1 METHODS

=cut

use parent qw(MVC::Neaf::X);

=head2 is_valid()

Returns true if data passed validation, false otherwise.

=cut

sub is_valid {
    my $self = shift;
    return !%{ $self->error };
};

=head2 data

Returns data that passed validation as hashref.
This MAY be incomplete, check is_valid() first.

=head2 data( "key" )

Get specific data item.

=head2 data( key => $newvalue )

Set specific data item.

=head2 error

Returns errors that occurred during validation.

=head2 error( "key" )

Get specific error item.

=head2 error( key => $newvalue )

Set specific error item. This may be used to invalidate a value
after additional checks, and will also reset is_valid.

=head2 raw

Returns raw input values as hashref.
Only keys subject to validation will be retained.

This may be useful for sending the data back for resubmission.

=head2 raw( "key" )

Get specific raw item.

=head2 raw( key => $newvalue )

Set specific raw item.

=cut

foreach (qw(data error raw)) {
    my $method = $_;

    my $code = sub {
        my $self = shift;

        my $hash = $self->{$method} ||= {};
        return $hash unless @_;

        my $param = shift;
        return $hash->{param} unless @_;

        $hash->{$param} = shift;
        return $self;
    };

    no strict 'refs'; ## no critic
    *$method = $code;
};

1;
