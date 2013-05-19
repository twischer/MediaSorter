#!/usr/bin/perl -w
use strict;
use warnings;
use utf8;
use File::Basename();
use LWP::UserAgent();

chdir(  File::Basename::dirname( $0 )  );
require MediaSorter;

my $MUSIC_PATH = "/home/timo/Musik/Neu";
#my $DEST_PATH = "/misc/grhnet/musik/wischer/good/";
my $DEST_PATH = "/home/timo/Musik/Server/good";
my $ERROR_PATH = "/home/timo/Musik/Fehler";

my @aszKeys = (0..9);
push @aszKeys, ('a'..'k');

my @aszDirectorys = (
	"Saufen",
	"Alternative",
	"Soul",
	"Funk",
	"Blues",
	"Dubstep",
	"Schlager",
	"House",
	"Disco",
	"Trance",
	"Electronic",
	"Hardstyle",
	"Techno",
	"RnB",
	"Rock",
	"Rap",
	"Reggae",
	"HipHop",
	"Dance",
	"Pop",
	);

my $szAutoAccept = "";

MediaSorter::Println("SORT GOOD MUSIC PLAYER\n");

MediaSorter::Println("Läd Verzeichnis $MUSIC_PATH'");
my @aszMusicFiles = MediaSorter::FindFiles( $MUSIC_PATH );


foreach my $szFile (@aszMusicFiles)
{
	MediaSorter::PlayerLoad( $szFile );
	
	my ($szGenre, $szGenreList) = GetGenreOfTrack($szFile);
	
	my ($szBasename, $szSuffix) = MediaSorter::GetBasename( $szFile );
	
#	my ($szArtist, $szTitle) = split(" - ", $szBasename);
#	$szTitle =~s/\.mp3$//i;
	my $szFreeDBGenre = "";#MediaSorter::getFreeDBGenre($szArtist, $szTitle);
	
	MediaSorter::Println("\n\n$szFile");
	MediaSorter::Println("Genre: $szFreeDBGenre | $szGenre ($szGenreList)\n");
	
	if ($szFreeDBGenre eq "")
	{
		$szFreeDBGenre = $szGenre;
	}
	
	MediaSorter::Println("y => $szFreeDBGenre");
	my $nCounter = 0;
	foreach my $szFolder (@aszDirectorys)
	{
		MediaSorter::Println( $aszKeys[$nCounter]." => $szFolder" );
		$nCounter++;
	}
	MediaSorter::Println(", => Zurückspulen");
	MediaSorter::Println(". => Vorspulen");
	MediaSorter::Println("r => Umbenennen");
	MediaSorter::Println("l => Löschen");
	MediaSorter::Println("v => Fehlerhaft");
	MediaSorter::Println("q => Beenden\n\n");
	
	my $fAutoAccept = 0;
	if ( (defined $szFreeDBGenre) and ($szFreeDBGenre ne "") and ($szAutoAccept =~ m/$szFreeDBGenre/) )
	{
		$fAutoAccept = 1;
	}
	
	my $bWorkingFile = 1;
	while ($bWorkingFile)
	{
		my $szInput = "y";
		if ($fAutoAccept == 0)
		{
			$szInput = MediaSorter::GetKey();
		}
		
		if ($szInput eq "q")
		{
			MediaSorter::Quit();
		}
		elsif ($szInput eq ",")
		{
			MediaSorter::PlayerRewind();
		}
		elsif ($szInput eq ".")
		{
			MediaSorter::PlayerForward();
		}
		elsif ($szInput eq "r")
		{
			$szBasename = MediaSorter::ChangeFileName( $szBasename );
		}
		elsif ($szInput eq "l")
		{
			MediaSorter::PlayerUnload();
			unlink($szFile);
			$bWorkingFile = 0;
		}
		elsif ($szInput eq "v")
		{
			MediaSorter::PlayerUnload();
			MediaSorter::MoveFile(  $szFile, $ERROR_PATH."/".$szBasename.$szSuffix  );
			$bWorkingFile = 0;
		}
		elsif ($szInput =~ m/^([0-9|a-z])$/ )
		{
			my $szDir = "";
			if ($1 eq "y")
			{
				$szDir = $szFreeDBGenre;
			}
			else
			{
				my $nFolder = 0;
				while ( ($1 ne $aszKeys[$nFolder++]) and ($nFolder <= $#aszKeys) )
				{
				}
				
				if ($nFolder <= $#aszKeys)
				{
					$szDir = $aszDirectorys[$nFolder-1];
				}
				else
				{
					die "Falsche Taste gedrückt.";
				}
			}
			
			my $szFolder = $DEST_PATH . "/" . $szDir . "/";
			
			if ($szBasename =~ m/^([A-Z])/i)
			{
				$szFolder .= uc($1);
			}
			else
			{
				$szFolder .= "-";
			}
			
			MediaSorter::PlayerUnload();
			MediaSorter::MoveFile( $szFile, $szFolder."/".$szBasename.$szSuffix );
			$bWorkingFile = 0;
		}
	}
}

MediaSorter::Quit();


sub GetGenreOfTrack
{
	my $szFile = shift;
	
	my $zsBaseName = File::Basename::basename( $szFile, (".mp3", ".MP3", ".Mp3", ".mP3") );
	my $szSearchPattern = "genre $zsBaseName";
	$szSearchPattern =~ s/ /\+/g;

	my $ua = LWP::UserAgent->new;
	$ua->timeout(10);
	$ua->env_proxy;
	$ua->agent('Mozilla/5.0');
	
	my $response = $ua->get("http://www.google.de/search?q=$szSearchPattern");
	my $szResult = $response->decoded_content;
	$szResult =~ s/<[^>]*>//g;
	$szResult =~ s/r\s*\&amp\;\s*b/rnb/ig;
	$szResult =~ s/[\W]//g;
	
	
	my %mpnGenreCounter = ();
	my @aszGenres = ();
	foreach my $szMatch (  split( m/genre/i, $szResult )  )
	{
		
		(my $szRegEx = $zsBaseName) =~ s/[\W]//g;
		if ( ($szMatch =~ m/^\s*(.{12})/) and ($szRegEx !~ m/^$1/) )
		{
			my $szGenre = $1;
			push @aszGenres, $szGenre;
			
			foreach my $szGenreMatch (@aszDirectorys)
			{
				if ($szGenre =~ m/$szGenreMatch/i)
				{
					$mpnGenreCounter{$szGenreMatch}++;
				}
			}
		}
	}
	
	my $nMaxGenreCount = 0;
	my $szMaxCountGenre = "";
	foreach my $szKey (@aszDirectorys)
	{
		if ( (defined $mpnGenreCounter{$szKey}) and ($mpnGenreCounter{$szKey} > $nMaxGenreCount) )
		{
			$nMaxGenreCount = $mpnGenreCounter{$szKey};
			$szMaxCountGenre = $szKey;
		}
	}
	
	my $szGenreList = join(", ", @aszGenres);
	if (defined $szMaxCountGenre)
	{
		return ($szMaxCountGenre, $szGenreList);
	}
	else
	{
		return ("", $szGenreList);
	}
}
