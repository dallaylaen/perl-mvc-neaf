package MVC::Neaf::Upload;

use strict;
use warnings;

=head1 NAME

MVC::Neaf::Upload - File upload object for Not Even A Framework

=head1 METHODS

Generally, this class isn't used directly; instead, it's returned by an
L<MVC::Neaf::Request> object.

=cut

our $VERSION = 0.1902;
use Carp;
use Encode;
use PerlIO::encoding;

=head2 new(%options)

%options may include:

=over

=item * id (required) - the form id by which upload is known.

=item * tempfile - file where upload is stored.

=item * handle - file handle opened for readin. One of these is required.

=item * filename - user-supplied filename. Don't trust this.

=item * utf8 - if set, all data read from the file will be utf8-decoded.

=back

=cut

# NOTE HACK
# This file uses inside-out objects to allow for diamond operator:
#     1) An object is represented by a blessed file handle;
#     2) All other fields are stored in a global hash;
#     3) DESTROY deletes entry from said hash.
# This is wrong, and shouldn't be done this way.
# This is experimental and may be removed in the future.
# See also t/*diamond*.t

my %new_opt;
my @copy_fields = qw(id tempfile filename utf8);
$new_opt{$_}++ for @copy_fields, "handle";
my %inside_out;
sub new {
    my ($class, %args) = @_;

    # TODO 0.19 add "unicode" flag to open & slurp in utf8 mode

    my @extra = grep { !$new_opt{$_} } keys %args;
    croak( "$class->new(): unknown options @extra" )
        if @extra;
    defined $args{id}
        or croak( "$class->new(): id option is required" );

    my $self;
    if ($args{tempfile}) {
        open $self, "<", $args{tempfile}
            or croak "$class->new(): Failed to open $args{tempfile}: $!";
    } elsif ($args{handle}) {
        open $self, "<&", $args{handle}
            or croak "$class->new(): Failed to dup handle $args{handle}: $!";
    } else {
        croak( "$class->new(): Either tempfile or handle option required" );
    };

    if ($args{utf8}) {
        local $PerlIO::encoding::fallback = Encode::FB_CROAK;
        binmode $self, ":encoding(UTF-8)"
    };
    bless $self, $class;

    delete $args{handle};
    $inside_out{$self} = \%args;

    return $self;
};

=head2 id()

Return upload id.

=cut

sub id {
    my $self = shift;
    return $inside_out{$self}{id};
};

=head2 filename()

Get user-supplied file name. Don't trust this value.

=cut

sub filename {
    my $self = shift;

    $inside_out{$self}{filename} = '/dev/null' unless defined $inside_out{$self}{filename};
    return $inside_out{$self}{filename};
};

=head2 size()

Calculate file size.

B<CAVEAT> May return 0 if file is a pipe.

=cut

sub size {
    my $self = shift;

    return $inside_out{$self}{size} ||= do {
        # calc size
        my $fd = $self->handle;
        my @stat = stat $fd;
        $stat[7] || 0;
    };
};

=head2 handle()

Return file handle, opening temp file if needed.

=cut

sub handle {
    my $self = shift;

    return $self;
};

=head2 content()

Return file content (aka slurp), caching it in memory.

B<CAVEAT> May eat up a lot of memory. Be careful...

B<NOTE> This breaks file current position, resetting it to the beginning.

=cut

sub content {
    my $self = shift;

    # TODO 0.30 remember where the  file was 1st time
    if (!defined $inside_out{$self}{content}) {
        $self->rewind;
        my $fd = $self->handle;

        local $/;
        my $content = <$fd>;
        if (!defined $content) {
            my $fname = $inside_out{$self}{tempfile} || $fd;
            croak( "Upload $inside_out{$self}{id}: failed to read file $fname: $!");
        };

        $self->rewind;
        $inside_out{$self}{content} = $content;
    };

    return $inside_out{$self}{content};
};

=head2 rewind()

Reset the file to the beginning. Will fail silently on pipes.

Returns self.

=cut

sub rewind {
    my $self = shift;

    my $fd = $self->handle;
    seek $fd, 0, 0;
    return $self;
};

sub DESTROY {
    my $self = shift;

    # TODO 0.30 kill the tempfile, if any?
    delete $inside_out{$self};
};

1;
