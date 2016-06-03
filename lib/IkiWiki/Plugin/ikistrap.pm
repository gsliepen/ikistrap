#!/usr/bin/perl
package IkiWiki::Plugin::ikistrap;

use warnings;
use strict;
use IkiWiki 3.00;

sub import {
	hook(type => "getsetup", id => "ikistrap", call => \&getsetup);
	hook(type => "refresh", id => "ikistrap", call => \&refresh);
	hook(type => "pagetemplate", id => "ikistrap", call => \&pagetemplate);
	hook(type => "preprocess", id => "progress", call => \&progress);
}

sub getsetup() {
	return
		plugin => {
			description => "Bootstrap 4 theme support",
			section => "web",
			safe => 1,
		},
		bootstrap_local => {
			description => "install Bootstrap css and js files locally instead of using bootstrapcdn?",
			example => 0,
			type => "boolean",
			default => 0,
			rebuild => 1,
		},
}

sub check($$) {
	my($basename, $href) = @_;
	my $filename = "$config{destdir}/$basename";
	return if(-e $filename);
	debug("Fetching missing $basename...");
	system("/usr/bin/curl -# \"$href\" -o \"$filename\"");
}

sub refresh() {
	return 0 unless($config{bootstrap_local});
	mkdir("$config{destdir}/css");
	mkdir("$config{destdir}/js");
	mkdir("$config{destdir}/fonts");
	check("css/bootstrap.min.css", "https://maxcdn.bootstrapcdn.com/bootstrap/4.0.0-alpha.2/css/bootstrap.min.css");
	check("js/bootstrap.min.js", "https://maxcdn.bootstrapcdn.com/bootstrap/4.0.0-alpha.2/js/bootstrap.min.js");
	check("css/font-awesome.min.css", "https://maxcdn.bootstrapcdn.com/font-awesome/4.5.0/css/font-awesome.min.css");
	check("fonts/fontawesome-webfont.eot", "https://maxcdn.bootstrapcdn.com/font-awesome/4.5.0/fonts/fontawesome-webfont.eot");
	check("fonts/fontawesome-webfont.woff2", "https://maxcdn.bootstrapcdn.com/font-awesome/4.5.0/fonts/fontawesome-webfont.woff2");
	check("fonts/fontawesome-webfont.woff", "https://maxcdn.bootstrapcdn.com/font-awesome/4.5.0/fonts/fontawesome-webfont.woff");
	check("fonts/fontawesome-webfont.ttf", "https://maxcdn.bootstrapcdn.com/font-awesome/4.5.0/fonts/fontawesome-webfont.ttf");
	check("fonts/fontawesome-webfont.svg", "https://maxcdn.bootstrapcdn.com/font-awesome/4.5.0/fonts/fontawesome-webfont.svg");
	check("js/jquery.min.js", "https://ajax.googleapis.com/ajax/libs/jquery/2.1.4/jquery.min.js");
	check("js/tether.min.js", "https://cdnjs.cloudflare.com/ajax/libs/tether/1.2.0/js/tether.min.js");
}

sub pagetemplate(@) {
	my %params = @_;
	my $template = $params{template};

	$template->param(bootstrap_local => $config{bootstrap_local});
}

# Emulate the progress plugin, but do it the HTML5 + Bootstrap way.
# Also allow setting an extra class attribute.
sub progress(@) {
	my %params = @_;
	my $percentage_pattern = qr/[0-9]+\%?/; # pattern to validate percentages
	my ($fill, $value, $max);

	if (defined $params{percent}) {
		$fill = $params{percent};
		($fill) = $fill =~ m/($percentage_pattern)/; # fill is untainted now
		$fill =~ s/%$//;
		if (! defined $fill || ! length $fill || $fill > 100 || $fill < 0) {
			error(sprintf(gettext("illegal percent value %s"), $params{percent}));
		}
		$value = $fill;
		$max = "100";
		$fill .= "%";
	} elsif (defined $params{totalpages} and defined $params{donepages}) {
		$max = pagespec_match_list($params{page}, $params{totalpages}, deptype => deptype("presence"));
		$value = pagespec_match_list($params{page}, $params{donepages}, deptype => deptype("presence"));

		if ($max == 0) {
			$fill = "100%";
		} else {
			$fill = sprintf("%u%%", $value / $max * 100);
		}
	} else {
		error(gettext("need either `percent` or `totalpages` and `donepages` parameters"));
	}

	my $class = "progress";
	if (defined $params{class}) {
		$class .= " $params{class}";
	}

	return <<EODIV
<progress class="$class" value="$value" max="$max">$fill</progress>
EODIV
}

1
