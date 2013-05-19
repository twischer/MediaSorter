#! /usr/bin/perl -w
use strict;
use warnings;
use utf8;
use File::Basename();

chdir(  File::Basename::dirname( $0 )  );
require MediaSorter;


my $MUSIC_PATH = "/home/timo/Musik/Radio";
my $DEST_PATH = "/home/timo/Musik/Neu";

my $HAT_LIST_FILE = "./hatlist.dat";

unless (-d $DEST_PATH)
{
	mkdir($DEST_PATH);
}

MediaSorter::Println("SORT RADIO PLAYER\n");

MediaSorter::Println("Läd Verzeichnis $MUSIC_PATH'");
my @aszMusicFiles = MediaSorter::FindFiles( $MUSIC_PATH );

my %aszHatList = MediaSorter::HistoryLoad( $HAT_LIST_FILE );

foreach my $szFile (@aszMusicFiles)
{
	my $szBasename = File::Basename::basename( $szFile );
	
	if (  ( defined $aszHatList{$szBasename} ) and ($aszHatList{$szBasename} == 1)  )
	{
		unlink($szFile);
		next;
	}
	
	MediaSorter::PlayerLoad( $szFile );
	
	MediaSorter::Println("\n\n$szBasename");
	
	
	MediaSorter::Println("y => Speichern");
	MediaSorter::Println("m => Löschen");
	MediaSorter::Println("n => Fehlerhaft");
	MediaSorter::Println("r => Neustarten");
	MediaSorter::Println(", => Zurückspulen");
	MediaSorter::Println(". => Vorspulen");
	MediaSorter::Println("q => Beenden\n");
	
	my $bWorkingFile = 1;
	while ($bWorkingFile)
	{
		my $szInput = MediaSorter::GetKey();
		
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
		elsif ($szInput eq "m")
		{
			MediaSorter::PlayerUnload();
			unlink($szFile);
			$aszHatList{$szBasename} = 1;
			$bWorkingFile = 0;
		}
		elsif ($szInput eq "n")
		{
			MediaSorter::PlayerUnload();
			unlink($szFile);
			$bWorkingFile = 0;
		}
		elsif ($szInput eq "y")
		{
			MediaSorter::PlayerUnload();
			MediaSorter::MoveFile( $szFile, $DEST_PATH."/".$szBasename );
#			File::Copy::move( $szFile, $DEST_PATH."/".$szBasename ) or warn "WARN: Lied nicht verschoben.\n";
			$bWorkingFile = 0;
		}
		elsif ($szInput eq "r")
		{
#			MediaSorter::PlayerLoad( $szFile );
		}
	}
}

MediaSorter::Quit();
