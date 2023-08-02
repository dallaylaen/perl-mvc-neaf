package MVC::Neaf::X::Form::LIVR;

use strict;
use warnings;
our $VERSION = '0.2901';

=head1 NAME

MVC::Neaf::X::Form::LIVR - LIVR-based form validator for Not Even A Framework.

=head1 DESCRIPTION

Do input validation using L<Validator::LIVR>.
Return an object with is_valid(), data(), error(), and raw() methods.

=head1 METHODS

=cut

# Don't require LIVR so far as it may be absent on client machine.
# Wait until we REALLY need it.

use parent qw(MVC::Neaf::X::Form);

=head2 new(\%profile)

Receives a LIVR validation profile. See L<Validator::LIVR>.

Additional options MAY be added later.

=cut

=head2 make_rules(\%profile)

Pre-process the rules. Returns a L<Validator::LIVR> object.

=cut

sub make_rules {
    my ($self, $rules) = @_;

    require Validator::LIVR;
    return Validator::LIVR->new( $rules );
};

=head2 do_validate( $data )

Actually validate the data. Returns clean data and errors generated by LIVR.

=cut

sub do_validate {
    my ($self, $data) = @_;

    return ( scalar $self->{rules}->validate( $data )
        , $self->{rules}->get_errors );
};

=head1 LICENSE AND COPYRIGHT

This module is part of L<MVC::Neaf> suite.

Copyright 2016-2023 Konstantin S. Uvarin C<khedin@cpan.org>.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.

=cut

1;
