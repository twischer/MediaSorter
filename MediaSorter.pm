package MediaSorter;

use strict;
use warnings;
use utf8;
use File::Find();
use Term::ReadKey();
use Storable();
use File::stat();
use POSIX();
use Time::HiRes();
use Glib();
use GStreamer();
use Text::Levenshtein();
use Term::ReadLine();
use LWP::UserAgent();
GStreamer->init();


my $pPlayer;

########################################
sub HistoryLoad
########################################
{
	my $szFile = shift;
	
	if (-f $szFile)
	{
		return %{ Storable::retrieve( $szFile ) };
	}
	else
	{
		return ();
	}
}

########################################
sub HistorySave
########################################
{
	my $szFile = shift;
	my $paszHistory = shift;
	
	Storable::store( $paszHistory, $szFile );
}

########################################
sub PlayerLoad
########################################
{
	my $szFile = shift;
	
	unless (defined $pPlayer)
	{
		$pPlayer = GStreamer::ElementFactory->make("playbin2", "player");
#		my $pobjOutput = GStreamer::ElementFactory->make("alsasink", "output");
#		$pobjOutput->set_property( "device", "iec958:CARD=NVidia,DEV=0" );
#		$pPlayer->set_property("audio-sink", $pobjOutput );
	}
	
	PlayerUnload();
	
	$pPlayer->set_property(  "uri", Glib::filename_to_uri( $szFile, "localhost" )  );
	$pPlayer->set_state("playing");
}

########################################
sub PlayerUnload
########################################
{
	if (defined $pPlayer)
	{
		$pPlayer->set_state("null");
	}
}

########################################
sub PlayerForward
########################################
{
	my $fLastVolume = $pPlayer->get_property( "volume" );
	$pPlayer->set_property( "volume", 0.0 );
	$pPlayer->seek(1.0, 'GST_FORMAT_TIME', 'GST_SEEK_FLAG_FLUSH', 'GST_SEEK_TYPE_CUR', 10_000_000_000, 'GST_SEEK_TYPE_NONE', 0);
	
	Time::HiRes::sleep( 0.1 );
	$pPlayer->set_property( "volume", $fLastVolume );
}

########################################
sub PlayerRewind
########################################
{
	$pPlayer->seek(1.0, 'GST_FORMAT_TIME', 'GST_SEEK_FLAG_FLUSH', 'GST_SEEK_TYPE_CUR', -5 * 1000000000, 'GST_SEEK_TYPE_NONE', -1);
}

########################################
sub GetKey
########################################
{
	Term::ReadKey::ReadMode('cbreak');
	my $szInput = Term::ReadKey::ReadKey(0);
	Term::ReadKey::ReadMode('normal');
	
	return $szInput;
}

########################################
sub FindFiles
########################################
{
	my ($szDir, $fReturnFileAndBasename, $fConvertWMAToMP3) = @_;
	
	unless (defined $fReturnFileAndBasename)
	{
		$fReturnFileAndBasename = 0;
	}
	
	unless (defined $fConvertWMAToMP3)
	{
		$fConvertWMAToMP3 = 0;
	}
	
	my @aFindFiles = ();
	File::Find::find (
		sub 
		{
			my $szFile = $File::Find::name;
			
			# WMA zu MP3 konvertieren wenn die aktuelle Datei 
			if ( $fConvertWMAToMP3 == 1 and (my $szMP3File = $szFile) =~ s/\.wma$/.mp3/i  )
			{
				system("ffmpeg -i \"".$szFile."\" -ab 192000 \"".$szMP3File."\" -map_meta_data 0:0");
				
				if ($? == 0)
				{
					unlink ($szFile);
					$szFile = $szMP3File;
				}
				else
				{
					die "FATAL: Could not convert WMA file: $!";
				}
			}
			
			
			if ( $szFile =~ m/\.mp3$/i or $szFile =~ m/\.flac$/i )
			{
				utf8::decode( $szFile );
				$szFile =~ s/\\/\//g;
				
				if ($fReturnFileAndBasename == 1)
				{
					my $szBasename = lc( GetBasename($szFile) );
					push @aFindFiles, [ $szFile, $szBasename ];
				}
				else
				{
					push @aFindFiles, $szFile;
				}
			}
			Print(".") if ( (@aFindFiles % 100) == 0 );
		}, 
		$szDir
	);
	return @aFindFiles;
}

########################################
sub GetBasename
########################################
{
	my ($szFile) = @_;
	
	my ($name, undef, $suffix) = File::Basename::fileparse($szFile, qr/\.[^.]*/);
	
	if (wantarray())
	{
		return ( $name, lc($suffix) );
	}
	else
	{
		return $name;
	}
}

########################################
sub Print
########################################
{
	my ($szText) = @_;
	
	utf8::encode( $szText );
	print STDERR $szText;
}

########################################
sub Println
########################################
{
	my ($szText) = @_;
	
	
	$szText = "" unless (defined $szText);
	Print( $szText."\n" );
}

########################################
sub MoveFile
########################################
{
	my ($szSource, $szDest, $fWaitUntilMoved) = @_;
	
	$szSource =~ s/\$/\\\$/g;
	$szSource =~ s/`/\\`/g;
	$szSource =~ s/\"/\\\"/g;
	$szDest =~ s/\$/\\\$/g;
	
	Println("Move\t'".$szSource."'\nto\t'".$szDest."'");
    
    my $szDestDir = File::Basename::dirname( $szDest );
    my $szCmd = "mkdir -p \"".$szDestDir."\" && mv \"".$szSource."\" \"".$szDest."\"";
	
	if ( (defined $fWaitUntilMoved) and ($fWaitUntilMoved == 1) )
	{
        my $nReturn = system($szCmd);
		unless ($nReturn == 0)
		{
			die "FATAL: Moving file '$szSource' to '$szDest' failed!\r\n";
		}
	}
	else
	{
        system($szCmd." &");
	}
}

########################################
sub MoveFileAddNumberIfExisting
########################################
{
	my ($szSource, $szDest, $szDestSuffix, $fWaitUntilMoved) = @_;
	
	
	if (-e $szDest.$szDestSuffix)
	{
		my $nCounter = 0;
		while (-e $szDest."_".$nCounter.$szDestSuffix)
		{
			$nCounter++;
		}
		$szDest .= "_".$nCounter;
	}
	
	MoveFile( $szSource, $szDest.$szDestSuffix, $fWaitUntilMoved );
}

########################################
sub GetDateOfFile
########################################
{
	my ($szFile) = @_;
	
	if (defined $szFile)
	{
		my $pobjFileStat = File::stat::stat( $szFile );
		if (defined $pobjFileStat)
		{
			my $nFileTime = $pobjFileStat->mtime();
			return POSIX::strftime( "%Y-%02m-%02e %H:%M:%S ", localtime($nFileTime) );
		}
		else
		{
			return "n/a";
		}
	}
	else
	{
		return "n/a";
	}
}

########################################
sub GetDiffOfStrings
########################################
{
	my ($szString1, $nString1Length, $szString2, $nMultiplier) = @_;
	
	my $nDiff = Text::Levenshtein::distance( $szString1, $szString2 );
		
	my $nString2Length = length( $szString2 );
	if ( $nString1Length >= $nString2Length )
	{
		$nDiff /= $nString1Length;
	}
	else
	{
		$nDiff /= $nString2Length;
	}
	$nDiff *= $nMultiplier;
	
	return $nDiff;
}

########################################
sub ChangeFileName
########################################
{
	my ($szFileName) = @_;
	
	utf8::encode( $szFileName );

	my $objTerm = Term::ReadLine->new("Rename file name");
	my $szNewFileName = $objTerm->readline("Umbenennen: ", $szFileName);
	
	utf8::decode( $szNewFileName );
	
	return $szNewFileName;
}

########################################
sub Quit
########################################
{
	MediaSorter::Println("Beendet.");
	exit;
}

########################################
sub getFreeDBGenre
########################################
{
	my ($szArtist, $szTitle) = @_;
	
	
	my $szURL = getFreeDBDiscURL($szArtist, $szTitle);
	
	my $ua = LWP::UserAgent->new();
	my $req = HTTP::Request->new(GET => $szURL);	
	my $response = $ua->request($req);			
	
	if ($response->is_success)
	{
		my $data = $response->content;
		
		if ($data =~ m/DGENRE=(.*)/i)
		{
			return $1;
		}
	}
	
	return "";
}

########################################
sub getFreeDBDiscURL
########################################
{
	my ($szArtist, $szTitle) = @_;
	
	my @keywords = split( m/ /, @_ );
	
	my $url = 'http://www.freedb.org/freedb_search.php?&fields=artist&fields=title&allcats=YES&allfields=NO&grouping=none';
	
	$url .="&words=".shift(@keywords);
	for my $word (@keywords) {
		$url .= "+".$word;
	}
	
	
	my $ua = LWP::UserAgent->new();
	my $req = HTTP::Request->new(GET => $url);	
	my $response = $ua->request($req);
	if ($response->is_success) {				
		my $data = $response->content;	
		
		my $szCDRegex = qr/<a href=\"\/freedb_search\.php[^\"]*\" class=searchResultTopLinkA onclick=\"[^\"]+\" id=\"[^\"]+\" (title=\"[^\"]+\")>[^<]+<\/a>/is;
		my $szURLRegex = qr/<a href=\"(http:\/\/www.freedb.org\/freedb\/[^\/]+\/[^\/]+)\">[^<]+<\/a>/is;
		my $szTitleRegex = qr/<tr><td style=\"[^\"]+\">\d+\.<\/td><td style=\"[^\"]+\">([^<]+)<\/td><td align=right nowrap>[^<]+<\/td><\/tr>/is;
		
		my @aszDiscs = ($data =~ m/$szCDRegex|$szURLRegex|$szTitleRegex/gs);
		
		my $szCurCD = "";
		my $szCurURL = "";
		my $szFirstBestURL = "";
		foreach my $szDiscInfo (@aszDiscs)
		{
			next unless(defined $szDiscInfo);
			
			if ($szDiscInfo =~ m/title=\"([^\/]+)/)
			{
				$szCurCD = $1;
				
				if (  GetDiffOfStrings($szCurCD, length($szCurCD), $szArtist, 100) > 15  )
				{
					$szCurCD = "";
				}
			}
			elsif ($szCurCD ne "")
			{
				if ($szDiscInfo =~ m/http/)
				{
					$szCurURL = $szDiscInfo;
					$szFirstBestURL = $szCurURL if ($szFirstBestURL eq "");
				}
				elsif ($szCurURL ne "")
				{
					$szDiscInfo =~ s/\(.*$//g;
					if (  GetDiffOfStrings($szDiscInfo, length($szDiscInfo), $szTitle, 100) <= 10  )
					{
						return $szCurURL;
					}
				}
			}
		}
		return $szFirstBestURL;
	}
	else
	{
		return "";
	}
}

1;