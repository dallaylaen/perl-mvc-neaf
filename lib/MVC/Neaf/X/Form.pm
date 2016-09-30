package MVC::Neaf::X::Form;

use strict;
use warnings;
our $VERSION = 0.0801;

=head1 NAME

MVC::Neaf::X::Form - Form validator for Not Even A Framework

=head1 CAUTION

This module should be moved into a separate distribution or (ideally)
merged with an existing module with similar functionality.

Possible candidates include L<Validator::LIVR>, L<Data::FormValidator>,
L<Data::CGIForm>, and more.

=head1 DESCRIPTION

Ths module provides hashref validation mechanism that allows for
showing per-value errors,
post-validation user-defined checks,
and returning the original content for resubmission.

=head1 SINOPSYS

    use MVC::Neaf::X::Form;

    # At the start of the application
    my $validator = MVC::Neaf::X::Form->new( \%profile );

    # Much later, multiple times
    my $form = $validator->validate( \%user_input );

    if ($form->is_valid) {
        do_intended_stuff( $form->data ); # a hashref
    } else {
        display_errors( $form->error ); # a hashref
        show_form_for_resubmission( $form->raw ); # also a hashref
    };

As you can see, nothing here has anything to do with http or html,
it just so happens that the above pattern is common in web applications.

=head1 METHODS

=cut

use parent qw(MVC::Neaf::X);
use MVC::Neaf::X::Form::Data;

=head2 new( \%profile )

%profile must be a hash with keys korresponding to the data being validated,
and values in the form of either regexp, [ regexp ], or [ required => regexp ].

Regular expressions are accepted in qr(...) and string format, and will be
compiled to only match the whole line.

B<NOTE> One may need to pass qr(...)s in order to allow multiline data
(e.g. in textarea).

B<NOTE> Format may be subject to extention with extra options.

=cut

sub new {
    my ($class, $profile) = @_;

    my %regexp;
    my %required;

    foreach (keys %$profile) {
        my $spec = $profile->{$_};
        if (ref $spec eq 'ARRAY') {
            if (@$spec == 1) {
                $regexp{$_} = _mkreg( $spec->[-1] );
            } elsif (@$spec == 2 and lc $spec->[0] eq 'required') {
                $regexp{$_} = _mkreg( $spec->[-1] );
                $required{$_}++;
            } else {
                $class->my_croak("Invalid validation profile for value $_");
            };
        } else {
            # plain or regexp
            $regexp{$_} = _mkreg( $spec );
        };
    };

    # mangle profile
    return bless {
        regexp => \%regexp,
        required => \%required,
        known_fields => [ keys %regexp ],
    }, $class;
};

sub _mkreg {
    my $str = shift;
    return qr/^$str$/;
};

=head2 validate( \%data )

Returns a MVC::Neaf::X::Form::Data object with methods:

=over

=item * is_valid - true if validation passed.

=item * data - data that passed validation as hash
(MAY be incomplete, must check is_valid() before usage).

=item * error - errors encountered.
May be extended if called with 2 args.
(E.g. failed to load an otherwise correct item from DB).
This also affects is_valid.

=item * raw - user params as is. Only the known keys end up in this hash.
Useful to send data back for resubmission.

=back

=cut

sub validate {
    my ($self, $data) = @_;

    my (%raw, %clean, %error);
    foreach ( $self->known_fields ) {
        if (!defined $data->{$_} ) {
            $error{$_} = 'REQUIRED' if $self->{required}{$_};
            next;
        };

        $raw{$_} = $data->{$_};

        if ($data->{$_} =~ $self->{regexp}{$_}) {
            $clean{$_} = $data->{$_};
        } else {
            $error{$_} = 'BAD_FORMAT';
        };
    };

    return MVC::Neaf::X::Form::Data->new(
        raw => \%raw, data=>\%clean, error => \%error,
    );
};

=head2 known_fields()

Returns list of known fields.

=cut

sub known_fields {
    my $self = shift;
    return @{ $self->{known_fields} };
};

1;
