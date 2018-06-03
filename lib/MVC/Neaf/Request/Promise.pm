package MVC::Neaf::Request::Promise;

use strict;
use warnings;

=head1 NAME

MVC::Neaf::Request::Promise - asyncronous request frontend for
in Not Even A Framework

=head1 METHODS

=cut

use Carp;

use parent qw(MVC::Neaf::Util::Base);

=head2 error

Same as request->error, but no immediate C<die> - wait until
response is requested.

=cut

sub error {
    my ($self, $error) = @_;

    $self->{backend}->_set_ready($error);
};

=head2 return

Return a value via $reques->reply.

=cut

sub return {
    my ($self, $value) = @_;

    $self->{backend}->_set_reply( $value );
    $self->{backend}->_set_ready();
};

our $AUTOLOAD;
sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    croak "No such method $method"
        if $method =~ /^_/;

    my $sub = sub {
        my $self = shift;
        $self->{backend}->$method(@_);
    };

    no strict 'refs'; ## no critic
    *$method = $sub;
    goto &$sub;
};

sub DESTROY {
    my $self = shift;
    $self->error( "510 Timeout" );
};

=head1 LICENSE AND COPYRIGHT

This module is part of L<MVC::Neaf> suite.

Copyright 2016-2018 Konstantin S. Uvarin C<khedin@cpan.org>.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.

=cut

1;
