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



my $PATH = "/misc/grh/games/wischer/Ultrastar Deluxe/songs/Unsortiert";
my $EXISTING_PATH = "/misc/grh/games/wischer/Ultrastar Deluxe/- Doppelt";
my $THRESHOLDE = 10;


MediaSorter::Println("MOVE SAME FILE\n");

MediaSorter::Println("Läd Verzeichnis $PATH");
my @aszFiles = File::Glob::glob( $PATH."/*" );
while ( my $szFile = shift @aszFiles )
{
	utf8::decode($szFile);
	my ($szBase, $szDir) = File::Basename::fileparse( $szFile );
	my $szBaseLength = length( $szBase );
	
	
	my $nMinDiff = 100;
	my $szMinDiffFile = "";
	my $szMinDiffBase = "";
	foreach my $szCompFile (@aszFiles)
	{
		utf8::decode($szCompFile);
		my ($szCompBase, $szCompDir) = File::Basename::fileparse( $szCompFile );
		
		my $nDiff = MediaSorter::GetDiffOfStrings( $szBase, $szBaseLength, $szCompBase, 100.0 );
		
		if ($nDiff < $nMinDiff)
		{
			$nMinDiff = $nDiff;
			$szMinDiffFile = $szCompFile;
			$szMinDiffBase = $szCompBase;
			
			last if ($nMinDiff <= $THRESHOLDE);
		}
	}
	
	if ($nMinDiff <= $THRESHOLDE)
	{
		MediaSorter::Println("1: ".$szBase);
		MediaSorter::Println("2: ".$szMinDiffBase);
		MediaSorter::Println("1: ".$szFile);
		MediaSorter::Println("2: ".$szMinDiffFile);
		MediaSorter::Println("Diff: ".$nMinDiff);
		
		my $szFileToMove = "";
		my $szBaseToMove = "";
#		if ($szFile =~ m/Unsortiert/i or $szFile =~ m/diZZy/i)
#		{
			$szFileToMove = $szFile;
			$szBaseToMove = $szBase;
#		}
#		elsif ($szMinDiffFile =~ m/Unsortiert/i or $szMinDiffFile =~ m/diZZy/i)
#		{
#			$szFileToMove = $szMinDiffFile;
#			$szBaseToMove = $szMinDiffBase;
#		}
#		
#		if (-e $szFileToMove)
#		{
			MediaSorter::MoveFileAddNumberIfExisting( $szFileToMove, $EXISTING_PATH."/".$szBaseToMove, "", 1 );
#		}
	}
	
	MediaSorter::Println("\n");
}

MediaSorter::Quit();
