#!/usr/bin/perl
package IkiWiki::Plugin::ikistrap;

use warnings;
use strict;
use IkiWiki 3.00;

sub import {
	hook(type => "checkconfig", id => "ikistrap", call => \&checkconfig);
	hook(type => "getsetup", id => "ikistrap", call => \&getsetup);
	hook(type => "refresh", id => "ikistrap", call => \&refresh);
	hook(type => "pagetemplate", id => "ikistrap", call => \&pagetemplate);
	hook(type => "preprocess", id => "progress", call => \&progress);
}

sub checkconfig() {
        if (! defined $config{bootstrap_js}) {
                $config{bootstrap_js} = 1;
        }
}

sub getsetup() {
	return
		plugin => {
			description => "Bootstrap 4 theme support",
			section => "web",
			safe => 1,
		},
		bootstrap_local => {
			description => "Install Bootstrap css and js files locally instead of using bootstrapcdn?",
			example => 0,
			type => "boolean",
			default => 0,
			rebuild => 1,
		},
		bootstrap_js => {
			description => "Load Bootstrap's Javascript helpers?",
			example => 0,
			type => "boolean",
			default => 1,
			rebuild => 1,
		}
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
	mkdir("$config{destdir}/fonts");
	check("css/bootstrap.min.css", "https://maxcdn.bootstrapcdn.com/bootstrap/4.1.0/css/bootstrap.min.css");
	check("css/font-awesome.min.css", "https://maxcdn.bootstrapcdn.com/font-awesome/4.7.0/css/font-awesome.min.css");
	check("fonts/fontawesome-webfont.eot", "https://maxcdn.bootstrapcdn.com/font-awesome/4.7.0/fonts/fontawesome-webfont.eot");
	check("fonts/fontawesome-webfont.woff2", "https://maxcdn.bootstrapcdn.com/font-awesome/4.7.0/fonts/fontawesome-webfont.woff2");
	check("fonts/fontawesome-webfont.woff", "https://maxcdn.bootstrapcdn.com/font-awesome/4.7.0/fonts/fontawesome-webfont.woff");
	check("fonts/fontawesome-webfont.ttf", "https://maxcdn.bootstrapcdn.com/font-awesome/4.7.0/fonts/fontawesome-webfont.ttf");
	check("fonts/fontawesome-webfont.svg", "https://maxcdn.bootstrapcdn.com/font-awesome/4.7.0/fonts/fontawesome-webfont.svg");

	return 0 unless($config{bootstrap_js});
	mkdir("$config{destdir}/js");
	check("js/jquery.min.js", "https://code.jquery.com/jquery-3.3.1.slim.min.js");
	check("js/popper.min.js", "https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.14.0/umd/popper.min.js");
	check("js/bootstrap.min.js", "https://maxcdn.bootstrapcdn.com/bootstrap/4.1.0/js/bootstrap.min.js");
}

sub pagetemplate(@) {
	my %params = @_;
	my $template = $params{template};

	$template->param(bootstrap_js => $config{bootstrap_js});
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

	my $class = "progress-bar";
	if (defined $params{class}) {
		$class .= " $params{class}";
	}

	return <<EODIV
<p><div class="progress"><div class="$class" role="progressbar" style="width: $value%" aria-valuenow="$value" aria-valuemin="0" aria-valuemax="$max">$fill</div></div></p>
EODIV
}

1
