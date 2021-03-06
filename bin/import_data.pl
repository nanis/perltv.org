#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

use Path::Tiny qw(path);
use JSON::Tiny ();
use Data::Dumper qw(Dumper);

use lib path($0)->absolute->parent->parent->child('lib')->stringify;
use PerlTV::Tools qw(read_file youtube_thumbnail);

my %sources;
my %people;

my $json = JSON::Tiny->new;
import_people();
import_sources();
import_videos();
exit;


sub import_sources {
	my $dir = path($0)->absolute->parent->parent->child('data/sources');
	foreach my $f ($dir->children) {
		next if $f =~ /\.swp$/;
		my $source = read_file($f);
		$sources{ $f->basename } = $source;
	}
	path('sources.json')->spew_utf8( $json->encode(\%sources) );
}


sub import_people {
	my $dir = path($0)->absolute->parent->parent->child('data/people');
	foreach my $f ($dir->children) {
		next if $f =~ /\.swp$/;
		my $person = read_file($f);
		$people{ $f->basename } = $person;
	}
	path('people.json')->spew_utf8( $json->encode(\%people) );
}


sub import_videos {
	my $dir = path($0)->absolute->parent->parent->child('data/videos');
	my @videos;
	my @not_featured;
	my @featured;
	my %tags;
	my %modules;
	my %meta;
	foreach my $f ($dir->children) {
		next if $f =~ /\.swp$/;
		my $video = read_file($f);
		die "Missing source in $f" if not $video->{source};
		die "Unindentified source '$video->{source}' in $f"
			if not $sources{ $video->{source} };
		die "Missing speaker in $f" if not $video->{speaker};
		die "Unindentified speaker '$video->{speaker}' in $f"
			if not $people{ $video->{speaker} };

		#warn Dumper $video;
		my %entry = (
			title => $video->{title},
			path  => $f->basename,
		);
		if ($video->{language}) {
			$entry{language} = $video->{language};
		}
	
		my $thumbnail = $video->{thumbnail} || youtube_thumbnail($video->{id});

		if ($video->{featured}) {
			my %item = (
				id   => $video->{id},
				date => $video->{featured},
				path => $f->basename,
				thumbnail => $thumbnail,
			);
			push @featured, \%item;
		} else {
			push @not_featured, $f->basename;
		}
		if ($video->{tags}) {
			foreach my $tag (@{ $video->{tags} }) {
				push @{ $tags{lc $tag} }, \%entry;
			}
		}
		if ($video->{modules}) {
			foreach my $module (@{ $video->{modules} }) {
				push @{ $modules{$module} }, \%entry;
				push @{ $meta{modules}{$module} }, {
					title => $video->{title},
					url   => 'http://perltv.org/v/' . $f->basename,
					thumbnail => $thumbnail,
				};
			}
		}
	
		push @videos, {
			%entry,
			source  => $video->{source},
			speaker => $video->{speaker},
		};
	}
	
	@featured = sort { $b->{date} cmp $a->{date} } @featured;
	
	my %data = (
		_comment => 'This is a generated file, please do NOT edit directly',
		videos => [ sort { $a->{title} cmp $b->{title} } @videos ],
	);
	path('videos.json')->spew_utf8( $json->encode(\%data) );
	path('featured.json')->spew_utf8( $json->encode(\@featured) );
	path('tags.json')->spew_utf8( $json->encode(\%tags) );
	path('modules.json')->spew_utf8( $json->encode(\%modules) );
	path('public/meta.json')->spew_utf8( $json->encode(\%meta) );
	
	say "Latest featured: $featured[0]{date}\n";

	if (@not_featured) {
		say 'Not yet featured:';
		say for @not_featured;
	}
}

