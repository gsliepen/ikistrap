# Ikistrap, a Bootstrap 5 theme for ikiwiki

[Ikiwiki](https://ikiwiki.info/) is a very powerful [wiki](https://en.wikipedia.org/wiki/Wiki) compiler.
However, its default theme is very minimalistic.
Ikistrap is a theme that uses [Bootstrap](http://getbootstrap.com/) 5 to ensure you have a wiki that looks professional,
whether you are viewing it on your desktop computer or on your mobile phone.

To use ikistrap in your own wiki, just add the following to your setup file:

    templatedir: /path/to/ikistrap/templates
    underlaydir: /path/to/ikistrap/basewiki

Ikistrap comes with an example wiki that shows off its features,
and shows you how to integrate some Bootstrap 5 features into your `.mdwn` files.
Use the `Makefile` to compile the example wiki.  The example wiki relies on the
multimarkdown and imagemagick libraries for Perl.  On Debian, these are available
in the libtext-multimarkdown-perl and perlmagick packages.
