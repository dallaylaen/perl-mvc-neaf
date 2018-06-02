# NAME

MVC::Neaf [ni:f] stands for Not Even A Framework.

# OVERVIEW

Neaf offers a simple, yet powerful way to create simple web-applications.
By the lazy, for the lazy.

It has a lot of similarities to
[Dancer](https://metacpan.org/pod/Dancer2) and
[Kelp](https://metacpan.org/pod/Kelp).

**Model** is assumed to be a regular Perl module, and is totally out of scope.

**View** is assumed to have just one method, `render()`,
which receives a hashref and returns a pair of (content, content-type).

**Controller** is a function that takes one argument (the request)
and either returns a hash for rendering, or dies.

`die 403;` is a valid way to generate a configurable error page.

**Request** contains everything the application needs to know
about the outside world. 

# EXAMPLE

The following would produce a greeting message depending
on the `?name=` parameter.

    use strict;
    use warnings;
    use MVC::Neaf;

    get + post "/" => sub {
		my $req = shift;

		return {
			-template => \'Hello, [% name %]!',
			-type     => 'text/plain',
			name      => $req->param( name => qr/\w+/, "Stranger" ),
		},
    };

    neaf->run;

# FEATURES

* GET, POST, and HEAD requests; uploads; redirects; and cookies
are supported.
Not quite impressive, but it's 95% of what's needed 95% of the time.

* Template::Toolkit view out of the box;

* json/jsonp view out of the box;

* can serve raw content (e.g. generated images);

* can serve static files from disk or from memory.
No need for separate web server to test CSS and/or images.

* regex-checked query parameters and cookies out of the box.

* Easy to develop RESTful web-services.

# NOT SO BORING FEATURES

* Fine-grained hooks, helpers, and fallback return values
that may be restricted to specific routes;

* Powerful form validation tooling.
[Validator::LIVR](https://metacpan.org/pod/Validator::LIVR)
supported, but not required.

* CLI-based debugging via `perl <your_app.pl> --help|--list|--method GET`

* Sessions supported out of the box with cookie-based and SQL-based backends.

* Fancy error templates supported.

# MORE EXAMPLES

See [example](example/).

Neaf uses examples as an additional test suite.

No feature is considered complete until half a page code snipped is written
to demonstrate it.

# PHILOSOPHY

* Start out simple, then grow up.

* Data in, data out. A *function* should receive and *argument* and return
a *value* or *die*.

* Sane defaults. Everything can be configured, nothing needs to be.

* It's not software unless you can run it.

* Trust nobody. Validate the data.

* Force UTF8 where possible. It's 21st century.

# BUGS

This package is still under heavy development
(with a test coverage of about 80% though).

Use [github](https://github.com/dallaylaen/perl-mvc-neaf/issues)
or [CPAN RT](http://rt.cpan.org/NoAuth/ReportBug.html?Queue=MVC-Neaf)
to report bugs and propose features.

Bug reports, feature requests, and overall critique are welcome.

# CONTRIBUTING TO THIS PROJECT

Please see [STYLE.md](STYLE.md) for the style guide.

Please see [CHECKLIST](CHECKLIST) if you plan to release a version.

# ACKNOWLEDGEMENTS

[Eugene Ponizovsky](https://github.com/iph0)
had great influence over my understanding of MVC.

[Alexander Kuklev](https://github.com/akuklev)
gave some great early feedback
and also drove me towards functional programming and pure functions.

[Akzhan Abdulin](https://github.com/akzhan)
tricked me into making the hooks.

[Cono](https://github.com/cono)
made some early feedback and great feature proposals.

Ideas were shamelessly stolen from PSGI, Dancer, and Catalyst.

The CGI module was used heavily in the beginning of the project.

# LICENSE AND COPYRIGHT

Copyright 2016-2017 Konstantin S. Uvarin aka KHEDIN

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

