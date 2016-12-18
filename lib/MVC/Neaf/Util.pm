package MVC::Neaf::Util;

use strict;
use warnings;
our $VERSION = 0.14;

=head1 NAME

MVC::Neaf::Util - Some static functions for Not Even A Framework

=head1 DESCRIPTION

This module is probably of no use by itself. See L<MVC::Neaf>.

=head1 EXPORT

This module optionally exports anything it has.

=cut

use POSIX qw(strftime locale_h);

use parent qw(Exporter);
our @EXPORT_OK = qw(http_date canonize_path path_prefixes);


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

=head2 canonize_path( path, want_slash )

Convert '////fooo//bar/' to '/foo/bar' and '//////' to either '' or '/'.

=cut

# Search for CANONIZE for ad-hoc implementations of this (for speed etc)
sub canonize_path {
    my ($path, $want_slash) = @_;

    $path =~ s#/+#/#g;
    if ($want_slash) {
        $path =~ s#/$##;
        $path =~ s#^/*#/#;
    } else {
        $path =~ s#^/*#/#;
        $path =~ s#/$##;
    };

    return $path;
};

=head2 path_prefixes ($path)

List ('', '/foo', '/foo/bar') for '/foo/bar'

=cut

sub path_prefixes {
    my ($str, $rev) = @_;

    $str =~ s#^/*##;
    $str =~ s#/+$##;
    my @dir = split qr#/+#, $str;
    my @ret = ('');
    my $temp = '';

    push @ret, $temp .= "/$_" for @dir;

    return @ret;
};

1;
