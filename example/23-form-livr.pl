#!/usr/bin/env perl

use strict;
use warnings;

# Don't die if no LIVR present
my $has_livr = eval { require Validator::LIVR; 1; };

# These two are for debug only - see $dump below
use JSON::XS;
use Encode;

# always use latest and greatest Neaf
use FindBin qw($Bin);
use File::Basename qw(dirname basename);
use lib dirname($Bin)."/lib";
use MVC::Neaf;

my $script = "/cgi/".basename(__FILE__);

my $tpl = <<"TT";
<html>
<head>
    <title>Form validation test</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
</head>
<body>
<h1>Form validation test</h1>
[% IF valid %]<h2>Form valid!</h2>[% END %]
<form method="GET">
    [% INCLUDE field_input name="name" %]<br>
    [% INCLUDE field_input name="phone" %]<br>
    [% INCLUDE field_input name="email" %]<br>
    [% INCLUDE field_input name="email_again" %]<br>
    [% INCLUDE field_input name="country" %]<br>
    <input type="submit" value="Validate!">
</form>
<br><br>
[% HTML(dumper) %]

[% BLOCK field_input %]
<div>
[% IF error.\$name %]<span style="color: red">[% END %]
Enter [% name %]:
[% IF error.\$name %]</span>[% END %]
    <input name="[% name %]" value="[% HTML( values.\$name ) %]">
[% END %]
TT

my %replace = qw( & &amp; " &quot; < &lt; > &gt; );
my $replace_symb = join "", keys %replace;
sub HTML {
    my $text = shift;
    $text =~ s/([$replace_symb])/$replace{$1}/g;
    return $text;
};

$has_livr and MVC::Neaf->route( $script => sub {
    my $req = shift;

    # JSON::XS would encode the data, but so will our View processing
    # so avoid double encoding...
    my $dump = decode_utf8(encode_json(
        [$req->form_raw, "====>", $req->form, "+++++", $req->form_errors,]));

    return {
        -template => \$tpl,
        valid     => $req->form,
        values    => $req->form_raw,
        error     => $req->form_errors,
        dumper    => $dump,
        HTML      => \&HTML,
    };
}, form => {
    name => [ "required", { like => qr/^\w+/, } ],
    phone => [ "integer" ],
    email => [ "email" ],
    email_again => ["email", "required", { equal_to_field => "email" } ],
    country => [ "required", { max_length => 2 } ],
}, description => "LIVR-based form validation" );

MVC::Neaf->run;
