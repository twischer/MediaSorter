#!/usr/bin/perl -w
use strict;
use warnings;
use utf8;
use File::Glob();
use File::Basename();
use File::Spec();
use LWP::UserAgent();
use File::Find();

chdir(  File::Basename::dirname( $0 )  );
require MediaSorter;



my $VIDEO_PATH = "/misc/grh/video/neu";
my $DEST_PATH_FILME = "/misc/grh/video/filme";
my $DEST_PATH_SERIEN = "/misc/grh/serien";

my $EXISTING_DIR = $VIDEO_PATH."/0Doppelt";
my $SYMLINK_DIR = $VIDEO_PATH."/0Einsortiert";

my @IGNORE_FILES = ("0Doppelt", "0Einsortiert");


my @aszKeys = (0..9);
push @aszKeys, ('a'..'k');

my @aszDirectorys = (
	"Action",
	"Biografie",
	"Dokumentation",
	"Drama",
	"Erotik",
	"Horror",
	"Konzert",
	"Satire",
	"Abenteuer",
	"Animation",
	"Fantasy",
	"Komödie",
	"Musical",
	"Science Fiction",
	"Thriller",
	);

MediaSorter::Println("SORT VIDEO\n");

my %mpszArchiveVideosBase = ();

MediaSorter::Println("Läd Verzeichnis $VIDEO_PATH");
foreach my $szFile ( File::Glob::glob( $VIDEO_PATH."/*" ) )
{
	LoadArchive();
	
	utf8::decode($szFile);
	my ($szBaseName, $szBaseNameSuffix) = GetFormattedBasename( $szFile );
	
	
	my $fIngonreFile = 0;
	foreach my $szIgnoreFile (@IGNORE_FILES)
	{
		$fIngonreFile = 1 if ($szBaseName =~ m/$szIgnoreFile/i);
	}
	next if ($fIngonreFile == 1);
	
	
	my $fWorking = 1;
	while ($fWorking)
	{
		my @aszSimilarFiles = ListSimilarVideos($szBaseName);
		
		MediaSorter::Println("VIDEO TO SORT");
		my $szVideoInfo = PrintVideoSummary($szBaseName, $szFile);
		
		
		my ($szGenre, $szGenreList) = GetGenreOfFilm( $szBaseName );
		
		MediaSorter::Println("Genre: $szGenre ($szGenreList)\n");
		
		MediaSorter::Println("y => $szGenre");
		my $nCounter = 0;
		foreach my $szFolder (@aszDirectorys)
		{
			MediaSorter::Println( $aszKeys[$nCounter]." => $szFolder" );
			$nCounter++;
		}
		MediaSorter::Println("s => Serien");
		MediaSorter::Println("r => Umbenennen");
		MediaSorter::Println("v => Doppelt");
		MediaSorter::Println("q => Beenden");
		MediaSorter::Println();
		
		my $szInput =  MediaSorter::GetKey();
		
		if ($szInput eq "r")
		{
			$szBaseName = MediaSorter::ChangeFileName( $szBaseName );
		}
		elsif ($szInput eq "v")
		{
			my $szDest = $EXISTING_DIR."/".$szBaseName.$szVideoInfo;
			MediaSorter::MoveFileAddNumberIfExisting( $szFile, $szDest, $szBaseNameSuffix, 1 );
			
			$fWorking = 0;
		}
		elsif ($szInput eq "q")
		{
			MediaSorter::Quit();
		}
		elsif ($szInput eq "s")
		{
			my $szBasenameSuffixFile = $szBaseName . $szVideoInfo . $szBaseNameSuffix;
			my $szDestFile = $DEST_PATH_SERIEN . "/" . $szBasenameSuffixFile;
			MediaSorter::MoveFile( $szFile, $szDestFile, 1 );
			
			CreateSymlink( $szDestFile, $szBasenameSuffixFile );
			
			$fWorking = 0;
		}
		elsif ($szInput =~ m/^([0-9|a-z])$/ )
		{
			my $szDir = "";
			if ($szInput eq "y")
			{
				$szDir = $szGenre;
			}
			else
			{
				my $nFolder = 0;
				while ( ($szInput ne $aszKeys[$nFolder++]) and ($nFolder <= $#aszKeys) )
				{
				}
				
				if ($nFolder <= $#aszKeys)
				{
					$szDir = $aszDirectorys[$nFolder-1];
				}
				else
				{
					die "Falsche Taste gedrückt. ($szInput) ";
				}
			}
			
			if ($szDir eq "")
			{
				warn "Falsche Eingabe!\n";
			}
			else
			{
				my $szBasenameSuffixFile = $szBaseName . $szVideoInfo . $szBaseNameSuffix;
				my $szDestFile = $DEST_PATH_FILME . "/" . $szDir . "/" . $szBasenameSuffixFile;
				MediaSorter::MoveFile( $szFile, $szDestFile, 1 );
				
				CreateSymlink( $szDestFile, $szBasenameSuffixFile );
				
				$fWorking = 0;
			}
		}
	}
	
	MediaSorter::Println("\n");
}

MediaSorter::Quit();


sub LoadArchive
{
	MediaSorter::Println("Läd Verzeichnis $DEST_PATH_FILME und $DEST_PATH_SERIEN");
	%mpszArchiveVideosBase = ();
	foreach my $szAVideo ( File::Glob::glob($DEST_PATH_FILME ."/*/*"), File::Glob::glob($DEST_PATH_SERIEN ."/*") )
	{
		utf8::decode($szAVideo);
		
		my ($zsBaseName, $zsBaseNameSuffix) = GetFormattedBasename($szAVideo);
		
		$mpszArchiveVideosBase{$zsBaseName} = $szAVideo;
	}
}


sub GetGenreOfFilm
{
	my ($zsBaseName) = @_;
	
	
	my $szSearchPattern = "film genre $zsBaseName";
	$szSearchPattern =~ s/ /\+/g;

	my $ua = LWP::UserAgent->new;
	$ua->timeout(10);
	$ua->env_proxy;
	$ua->agent('Mozilla/5.0');
	
	my $response = $ua->get("http://www.google.de/search?q=$szSearchPattern");
	my $szResult = $response->decoded_content;
	$szResult =~ s/<[^>]*>//g;
	$szResult =~ s/[^\wäöüÄÖÜ]//g;
	
	
	my %mpnGenreCounter = ();
	my @aszGenres = ();
	foreach my $szMatch (  split( m/genre/i, $szResult )  )
	{
		
		(my $szRegEx = $zsBaseName) =~ s/[^\wäöüÄÖÜ]//g;
		if ( ($szMatch =~ m/^\s*(.{14})/) and ($szRegEx !~ m/^$1/) )
		{
			my $szGenre = $1;
			push @aszGenres, $szGenre;
			
			foreach my $szGenreMatch (@aszDirectorys)
			{
				(my $szGenreRegex = $szGenreMatch) =~ s/\s//g;
				
				if ($szGenre =~ m/$szGenreRegex/i)
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

sub GetFormattedBasename
{
	my ($szFile) = @_;
	
	
	my $szSuffixRegex = "";
	if (-f $szFile)
	{
		$szSuffixRegex = qr/\.[^.]{1,4}$/;
	}
	
	my ($szBase, $szDir, $szSuffix) = File::Basename::fileparse( $szFile, $szSuffixRegex );
	
	$szBase =~ s/\.|_/ /g;
	$szBase =~ s/\s+/ /g;
	
	# Wörter in klammern löschen
	$szBase =~ s/\([^\)]*\)//g;
	$szBase =~ s/\[[^\]]*\]//g;
	$szBase =~ s/\{[^\}]*\}//g;
	
	$szBase = SetRightCase($szBase);
	
	return ($szBase, lc($szSuffix));
}

sub SetRightCase
{
	my ($szName) = @_;
	
	my @aszWordsToDelete = (
		"dvdr",
		"german",
		"ac3",
		"5 1",
		"dubbed",
		"xvid",
		"co3d",
		"sg",
		"hdrip",
		"r5",
		"ld",
		"cineplexx",
		"md",
		"flowzn",
		"ppv",
		"xvi",
	);
	
	# Wörter in richtige Schreibweise umwandeln
	my @Words = split( " ", lc($szName) );
	$szName = "";
	foreach my $Word (@Words)
	{
		my $fIgnoreWord = 0;
		foreach my $szIgnWord (@aszWordsToDelete)
		{
			if ($szIgnWord eq $Word)
			{
				$fIgnoreWord = 1;
				last;
			}
		}
		
		unless ($fIgnoreWord)
		{
			$szName .= ucfirst($Word)." ";
		}
	}
	
	# Leerzeichen am Anfang und Ende löschen
	$szName =~ s/^ //g;
	$szName =~ s/ $//g;
	
	return $szName;
}

sub ListSimilarVideos
{
	my ($szBase) = @_;
	
	
	MediaSorter::Println("SIMILAR VIDEOS");
	
	my $szBaseLength = length($szBase);
	
	my %mpszVideoWithDiff = ();
	foreach my $szABase (keys %mpszArchiveVideosBase)
	{
		my $nDiff = int(  MediaSorter::GetDiffOfStrings( $szBase, $szBaseLength, $szABase, 100.0 )  );
		
		unless (defined $mpszVideoWithDiff{$nDiff})
		{
			$mpszVideoWithDiff{$nDiff} = [];
		}
		push @{ $mpszVideoWithDiff{$nDiff} }, $szABase;
	}
	
	my @aszSimilarFiles = ();
	my $nSimilarFiles = 0;
	my $nMinDiff = -1;
	foreach my $nDiff (sort {$a <=> $b} keys %mpszVideoWithDiff)
	{
		$nMinDiff = $nDiff if ($nMinDiff == -1);
		
		foreach my $szABase (  @{ $mpszVideoWithDiff{$nDiff} }  )
		{
			my $szFile = $mpszArchiveVideosBase{$szABase};
			PrintVideoSummary($szABase, $szFile);
			
			push @aszSimilarFiles, $szFile;
			
			$nSimilarFiles++;
		}
		
		last if ($nSimilarFiles >= 3);
	}
	
	MediaSorter::Println("MinDiff: ".$nMinDiff);
	MediaSorter::Println("SAME FILE FOUND") if ($nMinDiff <= 30);
	MediaSorter::Println();
	
	return @aszSimilarFiles;
}

sub PrintVideoSummary
{
	my ($szBase, $szFile) = @_;
	
	if (-d $szFile)
	{
		my $szDir = $szFile;
		
		# größte datei im verzeichnis suchen
		my $nSize = 0;
		File::Find::find(
		sub {
			my $szMediaFile = $File::Find::name;
			if (-f $szMediaFile)
			{
				my $nNewSize = (-s $szMediaFile);
				if ($nNewSize > $nSize)
				{
					$szFile = $szMediaFile;
					$nSize = $nNewSize;
				}
			}
		},
		$szDir );
		
	}
	
	MediaSorter::Println("Basename: '$szBase'");
	MediaSorter::Println("File: '$szFile'");
	
	my $szVideoInfo = "";
	open(my $hCmd, "ffmpeg -i \"$szFile\" 2>&1 |");
	while (my $szInfoLine = <$hCmd>)
	{
		if ( ($szInfoLine =~ m/Audio\:/) or ($szInfoLine =~ m/Duration\:/) )
		{
			MediaSorter::Print($szInfoLine);
		}
		elsif ($szInfoLine =~ m/Video\:/)
		{
			MediaSorter::Print($szInfoLine);
			
			if ($szInfoLine =~ m/1920/)
			{
				$szVideoInfo = " [1080p]";
			}
			elsif ($szInfoLine =~ m/1280/)
			{
				$szVideoInfo = " [720p]";
			}
		}
	}
	close($hCmd);
	
	
	MediaSorter::Println("VideoInfo: ".$szVideoInfo);
	MediaSorter::Println();
	
	return $szVideoInfo;
}

sub CreateSymlink
{
	my ($szFile, $szBaseName) = @_;
	
	
	my $szSymlink = $SYMLINK_DIR."/".$szBaseName;
	my $szRelPath = File::Spec->abs2rel($szFile, $SYMLINK_DIR);
	
	MediaSorter::Println("Create symlink $szSymlink to $szRelPath");
	chdir($SYMLINK_DIR) or die "FATAL: Could not change to dir $SYMLINK_DIR: $!";
	symlink($szRelPath, $szSymlink) or die "FATAL: Could not create symlink $szRelPath, $szSymlink: $!";
}
