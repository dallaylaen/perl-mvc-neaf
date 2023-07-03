package MVC::Neaf::Util::Dir;

use strict;
use warnings;

our $VERSION = 0.28;

=head1 NAME

MVC::Neaf::Util::Dir - an object that encapsulates extensible path.

=head1 DESCRIPTION

This is used internally by L<MVC::Neaf> to handle relative paths
without relying on current working directory.

=cut

use Carp;
use Cwd qw(abs_path getcwd);
use File::Basename qw(basename dirname);
use File::Spec;

=head1 METHODS

=head2 new( $dir )

$dir may be one of

=over

=item * undef - a warning is issued and cwd() is used

=item * an absolute path starting with '/' - this path is used

=item * a relative path starting with '.' - a path relative to the
calling file is calculated.

=back

=cut

sub new {
    my $class = shift;
    my $dir = shift; # TODO maybe options at some point

    if (!defined $dir or !length $dir) {
        $dir = getcwd();
        carp "Relying on cwd() is deprecated. Consider using `neaf root => '.';`. Defaulting to $dir";
    } elsif ($dir !~ /^\//) {
        my $relative;
        my $level = 0;
        while (1) {
            my @caller = caller($level++);
            last unless defined $caller[0];
            next if $caller[0] =~ /^MVC::Neaf/ or $caller[0]->isa('MVC::Neaf::Util::Base');
            next unless -f $caller[1];
            $relative = $caller[1];
            last;
        }
        if (!defined $relative) {
            $relative = getcwd();
            carp "Failed to find a suitable root for relative path. Consider using `neaf root => '/some/path';`. Defaulting to $relative";
        } else {
            $relative = dirname($relative);
        };
        $dir = abs_path( "$relative/$dir" );
    };

    return bless \$dir, $class;
};

=head2 path( $dir )

If absolute path is given, return it.

If relative path is given, append it to the base path given to new().

=cut

sub path {
    my ($self, $cont) = @_;
    return $cont =~ /^\// ? $cont : File::Spec->canonpath("$$self/$cont");
};

1;
