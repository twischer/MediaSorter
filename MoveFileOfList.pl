#!/usr/bin/perl -w
use strict;
use File::Basename;

chdir( dirname($0) );
require MusicSorter;


my $szDestDir = "/home/timo/Musik/Fehler2/";


open (my $hFile, "<./mp3val2.log") or die "$!";
while(<$hFile>)
{
	if (m/\"([^\"]+)\"/)
	{
		my $szSource = $1;
		my $szDest = $szDestDir . basename($szSource);
		print "File: $szSource\r\n$szDest\r\n\r\n";
		MusicSorter::MoveFile($szSource, $szDest);
	}
}
close ($hFile);
