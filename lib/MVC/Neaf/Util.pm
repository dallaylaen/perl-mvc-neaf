package MVC::Neaf::Util;

use strict;
use warnings;
our $VERSION = 0.1301;

=head1 NAME

MVC::Neaf::Util - Some static functions for Not Even A Framework

=head1 DESCRIPTION

This module is probably of no use itself. See L<MVC::Neaf>.

=head1 EXPORT

This module optionally exports anything it has.

=cut

use POSIX qw(strftime locale_h);

use parent qw(Exporter);
our @EXPORT_OK = qw(http_date);


=head2 http_date

Return a date in format required by HTTP standard for cookies
and cache expiration.

=cut

sub http_date {
    my $t = shift;
    my $locale = setlocale( LC_TIME, "C" );
    my $date = strftime( "%a, %d %b %Y %H:%M:%S GMT", gmtime($t));
    setlocale( LC_TIME, $locale );
    return $date;
};


