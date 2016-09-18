#!/usr/bin/perl
package IkiWiki::Plugin::recentchanges;

use warnings;
use strict;
use IkiWiki 3.00;
use Encode;
use HTML::Entities;

sub import {
	hook(type => "getsetup", id => "recentchanges", call => \&getsetup);
	hook(type => "checkconfig", id => "recentchanges", call => \&checkconfig);
	hook(type => "refresh", id => "recentchanges", call => \&refresh);
	hook(type => "pagetemplate", id => "recentchanges", call => \&pagetemplate);
	hook(type => "htmlize", id => "_change", call => \&htmlize);
	hook(type => "sessioncgi", id => "recentchanges", call => \&sessioncgi);
	# Load goto to fix up links from recentchanges
	IkiWiki::loadplugin("goto");
	# ... and transient as somewhere to put our internal pages
	IkiWiki::loadplugin("transient");
}

sub getsetup () {
	return
		plugin => {
			safe => 1,
			rebuild => 1,
		},
		recentchangespage => {
			type => "string",
			example => "recentchanges",
			description => "name of the recentchanges page",
			safe => 1,
			rebuild => 1,
		},
		recentchangesnum => {
			type => "integer",
			example => 100,
			description => "number of changes to track",
			safe => 1,
			rebuild => 0,
		},
}

sub checkconfig () {
	$config{recentchangespage}='recentchanges' unless defined $config{recentchangespage};
	$config{recentchangesnum}=100 unless defined $config{recentchangesnum};
}

sub refresh ($) {
	my %seen;

	# add new changes
	foreach my $change (IkiWiki::rcs_recentchanges($config{recentchangesnum})) {
		$seen{store($change, $config{recentchangespage})}=1;
	}
	
	# delete old and excess changes
	foreach my $page (keys %pagesources) {
		if ($pagesources{$page} =~ /\._change$/ && ! $seen{$page}) {
			unlink($IkiWiki::Plugin::transient::transientdir.'/'.$pagesources{$page}) || unlink($config{srcdir}.'/'.$pagesources{$page});
		}
	}
}

sub sessioncgi ($$) {
	my ($q, $session) = @_;
	my $do = $q->param('do');
	my $rev = $q->param('rev');

	return unless $do eq 'revert' && $rev;

	my @changes=$IkiWiki::hooks{rcs}{rcs_preprevert}{call}->($rev);
	IkiWiki::check_canchange(
		cgi => $q,
		session => $session,
		changes => \@changes,
	);

	eval q{use CGI::FormBuilder};
	error($@) if $@;
	my $form = CGI::FormBuilder->new(
		name => "revert",
		header => 0,
		charset => "utf-8",
		method => 'POST',
		javascript => 0,
		params => $q,
		action => IkiWiki::cgiurl(),
		stylesheet => 1,
		template => { template('revert.tmpl') },
		fields => [qw{revertmessage do sid rev}],
	);
	my $buttons=["Revert", "Cancel"];

	$form->field(name => "revertmessage", type => "text", size => 80);
	$form->field(name => "sid", type => "hidden", value => $session->id,
		force => 1);
	$form->field(name => "do", type => "hidden", value => "revert",
		force => 1);

	IkiWiki::decode_form_utf8($form);

	if ($form->submitted eq 'Revert' && $form->validate) {
		IkiWiki::checksessionexpiry($q, $session);
		my $message=sprintf(gettext("This reverts commit %s"), $rev);
		if (defined $form->field('revertmessage') &&
		    length $form->field('revertmessage')) {
			$message=$form->field('revertmessage')."\n\n".$message;
		}
		my $r = $IkiWiki::hooks{rcs}{rcs_revert}{call}->($rev);
		error $r if defined $r;
		IkiWiki::disable_commit_hook();
		IkiWiki::rcs_commit_staged(
			message => $message,
			session => $session,
		);
		IkiWiki::enable_commit_hook();
	
		require IkiWiki::Render;
		IkiWiki::refresh();
		IkiWiki::saveindex();
	}
	elsif ($form->submitted ne 'Cancel') {
	        $form->title(sprintf(gettext("confirm reversion of %s"), $rev));
		$form->tmpl_param(diff => encode_entities(scalar IkiWiki::rcs_diff($rev, 200)));
		$form->field(name => "rev", type => "hidden", value => $rev, force => 1);
		IkiWiki::showform($form, $buttons, $session, $q);
		exit 0;
	}

	IkiWiki::redirect($q, urlto($config{recentchangespage}));
	exit 0;
}

# Enable the recentchanges link.
sub pagetemplate (@) {
	my %params=@_;
	my $template=$params{template};
	my $page=$params{page};

	if (defined $config{recentchangespage} && $config{rcs} &&
	    $template->query(name => "recentchangesurl") &&
	    $page ne $config{recentchangespage}) {
		$template->param(recentchangesurl => urlto($config{recentchangespage}, $page));
		$template->param(have_actions => 1);
	}
}

# Pages with extension _change have plain html markup, pass through.
sub htmlize (@) {
	my %params=@_;
	return $params{content};
}

sub store ($$$) {
	my $change=shift;

	my $page="$config{recentchangespage}/change_".titlepage($change->{rev});

	# Optimisation to avoid re-writing pages. Assumes commits never
	# change (or that any changes are not important).
	return $page if exists $pagesources{$page} && ! $config{rebuild};

	# Limit pages to first 10, and add links to the changed pages.
	my $is_excess = exists $change->{pages}[10];
	delete @{$change->{pages}}[10 .. @{$change->{pages}}] if $is_excess;
	my $has_diffurl=0;
	$change->{pages} = [
		map {
			if (length $config{cgiurl}) {
				$_->{link} = "<a href=\"".
					IkiWiki::cgiurl(
						do => "goto",
						page => $_->{page}
					).
					"\" rel=\"nofollow\">".
					pagetitle($_->{page}).
					"</a>"
			}
			else {
				$_->{link} = pagetitle($_->{page});
			}
			if (defined $_->{diffurl} && length($_->{diffurl})) {
				$has_diffurl=1;
			}

			$_;
		} @{$change->{pages}}
	];
	push @{$change->{pages}}, { link => '...' } if $is_excess;
	
	if (length $config{cgiurl} &&
	    exists $IkiWiki::hooks{rcs}{rcs_preprevert} &&
	    exists $IkiWiki::hooks{rcs}{rcs_revert}) {
		$change->{reverturl} = IkiWiki::cgiurl(
			do => "revert",
			rev => $change->{rev}
		);
	}

	$change->{author}=$change->{user};
	my $oiduser=eval { IkiWiki::openiduser($change->{user}) };
	if (defined $oiduser) {
		$change->{authorurl}=$change->{user};
		$change->{user}=defined $change->{nickname} ? $change->{nickname} : $oiduser;
	}
	elsif (length $config{cgiurl}) {
		$change->{authorurl} = IkiWiki::cgiurl(
			do => "goto",
			page => IkiWiki::userpage($change->{author}),
		);
	}

	if (ref $change->{message}) {
		my $title = shift @{$change->{message}};
		$change->{title} = $title->{line};

		foreach my $field (@{$change->{message}}) {
			if (exists $field->{line}) {
				# escape html
				$field->{line} = encode_entities($field->{line});
				# escape links and preprocessor stuff
				$field->{line} = encode_entities($field->{line}, '\[\]');
			}
		}
	}

	# Fill out a template with the change info.
	my $template=template("change.tmpl", blind_cache => 1);
	$template->param(
		%$change,
		commitdate => displaytime($change->{when}, "%X %x"),
		wikiname => $config{wikiname},
	);
	
	$template->param(has_diffurl => 1) if $has_diffurl;

	$template->param(permalink => urlto($config{recentchangespage})."#change-".titlepage($change->{rev}))
		if exists $config{url};
	
	IkiWiki::run_hooks(pagetemplate => sub {
		shift->(page => $page, destpage => $page,
			template => $template, rev => $change->{rev});
	});

	my $file=$page."._change";
	writefile($file, $IkiWiki::Plugin::transient::transientdir, $template->output);
	utime $change->{when}, $change->{when}, $IkiWiki::Plugin::transient::transientdir.'/'.$file;

	return $page;
}

1
