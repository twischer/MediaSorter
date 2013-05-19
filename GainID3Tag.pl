#!/usr/bin/perl -w
use strict;
use warnings;
use utf8;
use Getopt::Long();
use File::Basename();
use File::Temp();
use MP3::Tag();
use MP3::Info();

MP3::Tag->config("write_v24" => 1);


chdir( File::Basename::dirname($0) );
require MediaSorter;

my $fFading = 0;
Getopt::Long::GetOptions(
	'fading'	=> \$fFading,
);

my $MUSIC_PATH = $ARGV[0];


print "GAIN and ID3-Tag\n\n";

print "Laed Verzeichnis $MUSIC_PATH'\n";
my @rgszMusicFiles = MediaSorter::FindFiles( $MUSIC_PATH );

my $nCounter = 1;
my $nCount = scalar @rgszMusicFiles;
foreach my $szFile (@rgszMusicFiles)
{
	print "\n\n( $nCounter | $nCount )\n";
	
	my $szFile2 = "\"$szFile\"";
	if ($szFile =~ m/\$/)
	{
		$szFile2 = "'$szFile'";
	}
	
	# id3 tags lesen
	my $pobjID3Read = MP3::Tag->new( $szFile );
    warn "WARN: ID3-Tag open failed '$szFile'." unless (defined $pobjID3Read);
	$pobjID3Read->get_tags();
	
	my $szPublisher = "";
	if (exists $pobjID3Read->{'ID3v2'})
	{
		($szPublisher) = $pobjID3Read->{'ID3v2'}->getFrame( "TENC" );
	}
	
	# lautstärke nominalisieren
	system("mp3gain -r -k $szFile2");
	
	# fade in and out
	if ($fFading)
	{
		my $szDir = File::Basename::dirname($szFile);
		my $szTmpFile = File::Temp::tempnam( $szDir, "tmp" );
		
		my $mpszInfo = MP3::Info::get_mp3info($szFile);
		my $nSecLen = $mpszInfo->{'SECS'} - 0.5;
		system("sox --multi-threaded -S $szFile2 -t mp3 '$szTmpFile' fade t 4 $nSecLen 2");
		if ($?)
		{
			die "FATAL: File $szFile2 not converted!";
		}
		unlink $szFile;
		rename($szTmpFile, $szFile);
	}
	
	
	# id3 tags löschen
	my $pobjID3 = MP3::Tag->new( $szFile );
	$pobjID3->get_tags();
	
	foreach my $szID ("ID3v1", "ID3v2")
	{
		if (exists $pobjID3->{$szID})
		{
			$pobjID3->{$szID}->remove_tag();
		}
	}
	
	# ID3 tag schrieben
	$pobjID3->new_tag("ID3v2");
	my $szFileName = File::Basename::basename( $szFile, (".mp3", ".MP3", ".Mp3", ".mP3") );
	if ( ($szFileName =~m/^(.*) \- (.*)$/) or ($szFileName =~m/^(.*)\-(.*)$/) )
	{
		my $szArtist = $1;
		utf8::decode( $szArtist );
		$pobjID3->{'ID3v2'}->artist( $szArtist );
		
		my $szTitle = $2;
		utf8::decode( $szTitle );
		$pobjID3->{'ID3v2'}->title( $szTitle );
	}
	else
	{
		warn "WARN: Could not detect artist and title!\r\n";
	}
	
	if ( (defined $szPublisher) and ($szPublisher ne "") )
	{
		$pobjID3->{'ID3v2'}->add_frame( "TENC", $szPublisher );
	}
	
	$pobjID3->{'ID3v2'}->write_tag();
	$pobjID3->close();
	
	$nCounter++;
}

print "Beendet.\n";

sub WriteTag
{
	
}

