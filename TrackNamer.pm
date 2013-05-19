package TrackNamer;

use strict;
use warnings;
use utf8;
use Memoize();

# Save the return values of this function (speed up)
Memoize::memoize('TrackNamer::ReadListFile');

# ReplaceWords array description
#	[ {Regex}, {ReplaceWord} ],
#	[  {RegexWithBrakets}, [ {FillWord1}, {FillWord2}, {FillWordN} ]  ],
#	[  [ {Exclusion1}, {Exclusion2}, ... , {ExclusionN}, {WorkerRegex} ], {ReplaceWord} ],
#	[  [ {Exclusion1}, {Exclusion2}, ... , {ExclusionN}, {WorkerRegexWithBrakets} ], [ {FillWord1}, {FillWord2}, {FillWordN} ]  ],

my @ReplaceWords = (
	["p!nk",					"pink"],
	
	GenHyphenRegex(),
	
	[qr/\./,					" "],			# Punkte in Dateinamen durch Leerzeichen erstezten
	[qr/\!/,					""],
	[qr/\?/,					""],
	[qr/\:/,					" "],
	[qr/\"/,					" "],
	[qr/\;/,					", "],
	[qr/\//,					"-"],
	[qr/–/,						"-"],
    [qr/—/,                     "-"],
	
	["mp3",						""],
	
	["%20",						" "],
	["%26",						"&"],
	["%27",						"'"],
	["%28",						"("],
	["%29",						")"],
	[qr/\%2C/i,					","],
					
	["\x92",					"'"],
	["\xB4",					"'"],
	["\xEB",					"e"],
	["\xF3",					"o"],
	
	[qr/\�/,					"'"],
	[qr/\`/,					"'"],
	[qr/\’/,					"'"],
	[qr/ž/i,					"'"],
	
	[qr/á|à|â|ã|å/i,			"a"],
	[qr/é|è|ê|ë/i,				"e"],
	[qr/í|ì|î|ï/i,				"i"],
	[qr/ó|ò|ô|õ/i,				"o"],
	[qr/ú|ù|û/i,				"u"],
	
	["___",						" feat "],		# Meistens soll der 2te "_" ein "&" sein
	[qr/dj[_|-]s[\s|_]/i,		"dj's "],
	["@",						" at "],
	["'n sync",					"n'sync"],
	["ronskispeed",				"ronski speed"],
	["groove's",				"grooves"],
	["mark 'oh",				"mark'oh"],
	["3oh3",					"3oh!3"],
	[qr/2gether/i,				"together"],
	[qr/dda/,					"Dream Dance Alliance"],
	[qr/h\s*-\s*blocks/i,	"H-Blockx"],
	[qr/salt\s*-\s*n\s*-\s*pepa/i,	"Salt'n'Pepa"],
	[qr/ac\s*\-\s*dc/i,			"acdc"],
	[qr/^(.*)\s*\&\s*(.*)$/i,	[" & "] ],
	[qr/\s'n'\s/i,				" and "],
	[ [ qr/e\s*-\s*40/i, qr/\-\s*\d+\s*\-/i ],		"-"],
	
	["_",						" "],
	[qr/\s+/,					" "],
	
	[qr/^(.*[\s|\-])'(\w.*)'(.*)$/,		[""] ],		# Hochkommers die den Titel einklammern löschen
	[qr/^(.*[\s|\-])''(\w.*)''(.*)$/,	[""] ],
	
	[qr/^(.*[^\s])-([^\s].*)$/,									[" - "] ],#  Vor und nach einem Bindestrich leerzeichen schreiben
	[qr/^(.*[^\s])\s-([^\s].*)$/,								[" - "] ],
	[qr/^(.*[^\s])-\s([^\s].*)$/,								[" - "] ],
	
	[qr/^(.*\smc)(\w.*)$/,						[" "] ],	# split the letters MC from the lastname
	
	GenMutatedVowelWordsRegex(),
	GenNumberWordsRegex(),
	[qr/^\s*/,						""],				# verschiedene Strings am Anfnag löschen
	[qr/^va\s*-/,					""],
	[qr/^clipgrab/,					""],
	[qr/^muzi4ka\s*com\s*-/,		""],
	[qr/^various\s*-/,				""],
	[qr/^various\s*artists\s*-/,	""],
	
	[qr/^the /,					""],			# Artikel am Anfang entfernen
	[qr/^der /,					""],
	[qr/^die /,					""],
	[qr/^das /,					""],
	
	[qr/^\s*\-(.*\-.*)$/,		[""] ],			# Bindestriche am Anfang löschen

	[qr/-\s*ind$/,				""],			# verschiedene Strings am Ende löschen
	[qr/-\s*musicloungec4to$/,	""],
	[qr/-\s*ministry$/,			""],
	[qr/-\s*ysp$/,				""],
	[qr/-\s*whoa$/,				""],
	[qr/-\s*unzensiert$/,		""],
	[qr/-\s*ft$/,				""],
	[qr/-\s*siq$/,				""],
	[qr/-\s*sds$/,				""],
	[qr/-\s*com$/,				""],
    [qr/\s*www\s?\S+\s?com/,    ""],
    [qr/\s*www\s?\S+\s?to/,    ""],
    [qr/-\s*mcny$/,				""],
	[qr/-\s*ute$/,				""],
	[qr/-\s*bymax$/,			""],
	[qr/-\s*fbe$/,				""],
	[qr/-\s*drd$/i,				""],
	[qr/-\s*caheso$/i,			""],
	[qr/-\s*olive$/i,			""],
	[qr/-\s*charts\s*to$/i,			""],
	[qr/-\s*$/,					""],			# Bindestriche am Ende löschen

	[qr/\([^\)]*\)/,			""],			# Wörter in klammern löschen
	[qr/\[[^\]]*\]/,			""],
	[qr/\{[^\}]*\}/,			""],
	[qr/\(.*$/,					""],			# Text, der nach einer offenen Klammer steht, löschen
	[qr/\[.*$/,					""],
	[qr/\{.*$/,					""],
	[qr/\)/,					""],			# Klammern die nicht geöffnet sondern nur geschlossen werden löschen
	[qr/\]/,					""],
	[qr/\}/,					""],
	);

my @ReplaceWords2 = (
	GenSpecialWordsRegex(),
	GenApostropheWordsRegex(),
	
	GenFeaturingRegex(),
	[qr/^(.*)\, (.*\s\-\s.*)$/,							[" feat "] ],
	[qr/^(.*)\; (.*\s\-\s.*)$/,							[" feat "] ],
	
	[qr/^([a-z])\sfeat\s([a-z]\s\-\s.*)$/i,				["&"] ],
	[qr/^(.*\s[a-z])\sfeat\s([a-z]\s\-\s.*)$/i,			["&"] ],
	[qr/^([a-z])\sfeat\s([a-z]\s.*\s\-\s.*)$/i,			["&"] ],
	[qr/^(.*\s[a-z])\sfeat\s([a-z]\s.*\s\-\s.*)$/i,		["&"] ],
	
	[qr/^(.*\s\-\s.*\s)\&(\s.*)$/,						["And"] ],
	[qr/^(.*\s\-\s.*\s)\+(\s.*)$/,						["And"] ],
	[qr/^(.*\s\-\s.*\s)feat(\s.*)$/i,					["And"] ],
	
	[qr/^(.*\-.*\s)U(\s.*)$/i,				["You"] ],
	[qr/^(.*\-.*\s)U$/i,					["You"] ],
	[qr/^(.*\-.*\s)Ur(\s.*)$/i,				["Your"] ],
	[qr/^(.*\-.*\s)Ur$/i,					["Your"] ],
	[qr/^(.*\-.*\s)R(\s.*)$/i,				["Are"] ],
	[qr/^(.*\-.*\s)R$/i,					["Are"] ],
	);


my %mpszKownAeUeOeWords = ();
foreach my $szWord (  ReadListFile( "./TrackNamerSpecialWords.lst" )  )
{
	foreach my $szKownAeUeOeWord ( $szWord =~ m/\S*[auo]e\S*/ig )
	{
		$mpszKownAeUeOeWords{$szKownAeUeOeWord} = 1;
	}
}

sub GetNewTrackName
{
	my ($szBasename, $fDebug) = @_;
	
	$szBasename = ConvertTrackName(  lc( $szBasename ), \@ReplaceWords, $fDebug  );
	$szBasename = SetRightCase( $szBasename );
	$szBasename = ConvertTrackName( $szBasename, \@ReplaceWords2, $fDebug );
	
	my $fFilenameHasChangeByUser = HasFilenameChangeByUser( $szBasename, $fDebug );
	
	
	return ($szBasename, $fFilenameHasChangeByUser);
}

sub ConvertTrackName
{
	my ( $FilenameNew, $paszReplaceWords, $fDebug ) = @_;
	
	my $nLoopsLeft = 6;
	my $szFilenameCmp = "";
	while ( ($szFilenameCmp ne $FilenameNew) and ($nLoopsLeft >= 0) )
	{
		$szFilenameCmp = $FilenameNew;
		
		# Zeichen und Wörter ersetzen
		foreach my $refWords ( @$paszReplaceWords )
		{
			my $szFilenameCmp2 = $FilenameNew;
			
			my $fCompareRegexMatched = 0;
			my $szRegex = "";
			if ( ref( $refWords->[0] ) eq "ARRAY" )
			{
				my @aszRegex = @{ $refWords->[0] };
				# Überprüfen ob die Regex nicht matchen
				# wenn einer passt Arbeiter-Regex nicht anwenden
				$szRegex = pop @aszRegex;
				foreach my $szCompareRegex (@aszRegex)
				{
					if ($FilenameNew =~ m/$szCompareRegex/i )
					{
						$fCompareRegexMatched = 1;
						last;
					}
				}
			}
			else
			{
				$szRegex = $refWords->[0];
			}
			
			if ( $FilenameNew =~ m/$szRegex/i and ($fCompareRegexMatched == 0) )
			{
				my @aszData = ($1, $2, $3, $4, $5, $6, $7, $8, $9);
				if (ref( $refWords->[1] ) eq "ARRAY")
				{
					my @aszReplaceData = @{ $refWords->[1] };
					my $ni = 0;
					
					$FilenameNew = "";
					foreach my $szString (@aszData)
					{
						last unless (defined $szString);
						
						$FilenameNew .= $szString;
						if (defined $aszReplaceData[$ni])
						{
							$FilenameNew .= $aszReplaceData[$ni];
						}
						$ni++;
					}
				}
				else
				{
					my $szReplacement = $refWords->[1];
					$FilenameNew =~ s/$szRegex/$szReplacement/gi;
				}
			}
			
			warn "DEBUG: Title changed to '$FilenameNew' by regex '$szRegex'.\r\n" if ( ($fDebug == 1) and ($szFilenameCmp2 ne $FilenameNew) );
		}
		
		$nLoopsLeft--;
	}
	
	if ($nLoopsLeft < 0)
	{
		die "FATAL: Problem by renaming of file '$FilenameNew'.";
	}
	
	return $FilenameNew;
}

sub SetRightCase
{
	my $FilenameNew = shift;
	
	# Wörter in richtige Schreibweise umwandeln
	my @Words = split(" ", $FilenameNew);
	$FilenameNew = "";
	foreach my $Word (@Words)
	{
		if (defined $Word)
		{
			my $Word2 = "";
			while ( $Word =~ m/^(.*)-(.*)$/ )
			{
				$Word = $1;
				$Word2 = "-".ucfirst($2).$Word2;
			}
			$FilenameNew .= ucfirst $Word;
			$FilenameNew .= $Word2;
		}
		
		$FilenameNew .= " ";
	}
	
	# Leerzeichen am Anfang und Ende löschen
	$FilenameNew =~ s/^ //g;
	$FilenameNew =~ s/ $//g;
	
	return $FilenameNew;
}

sub HasFilenameChangeByUser
{
	my ($szFilename, $fDebug) = @_;
	
	
	my $fFilenameHasChangeByUser = 0;
	
	# look for words which should possible contain an ä ö or ü
	my @aszPossibleWrongWords = ($szFilename =~ m/\S*[auo]e\S*/ig);
	foreach my $szWord (@aszPossibleWrongWords)
	{
		if ( (not defined $mpszKownAeUeOeWords{$szWord}) or ($mpszKownAeUeOeWords{$szWord} != 1) )
		{
			$fFilenameHasChangeByUser = 1;
			print "Word '".$szWord."' has possible to be changed" if ($fDebug == 1);
			last;
		}
	}

	# look for right count of -
	my @aszSpaces = ($szFilename =~ m/\s\-\s/g);
	if (@aszSpaces != 1)
	{
		$fFilenameHasChangeByUser = 1;
		print "Filename '".$szFilename."' has not exactly one -" if ($fDebug == 1);
	}
	
	
	
	return $fFilenameHasChangeByUser;
}

sub GenHyphenRegex
{
	my @aszRegex = ();
	
	my $nCount = 7;
	while ($nCount >= 0)
	{
		my $szMain = "[-|\.]([a-z])" x $nCount;
		push @aszRegex, [ qr/^([a-z])$szMain[-|\.](\s.*)$/,			[""] ];
		push @aszRegex, [ qr/^(.*\s[a-z])$szMain[-|\.](\s.*)$/,		[""] ];
		push @aszRegex, [ qr/^(.*\s[a-z])$szMain[-|\.]$/,			[""] ];
		push @aszRegex, [ qr/^([a-z])$szMain(\s.*)$/,			[""] ];
		push @aszRegex, [ qr/^(.*\s[a-z])$szMain(\s.*)$/,		[""] ];
		push @aszRegex, [ qr/^(.*\s[a-z])$szMain$/,				[""] ];
		
		$nCount--;
	}
	
	return @aszRegex;
}

sub GenMutatedVowelWordsRegex
{
	my @aszRegex = ();
	
	foreach my $szLine (  ReadListFile( "./TrackNamerSpecialWords.lst" )  )
	{
		if ($szLine =~ m/ä|ö|ü/i)
		{
			my $szOldWord = $szLine;
			$szOldWord =~ s/ä/(ae|ä)/gi;
			$szOldWord =~ s/ö/(oe|ö)/gi;
			$szOldWord =~ s/ü/(ue|ü)/gi;
			
			push @aszRegex, GetSpecialWordRegex( $szOldWord, $szLine, 0 );
		}
	}
	
	return @aszRegex;
}

sub GenFeaturingRegex
{
	my @aszRegex = ();
	foreach my $szWord ("featuring", "ft", "fe", "vs", "pr", "pts", "pres", "present", "presents", "meets", "feet", "and", "und", "mit", "with", "og", "\\&")
	{
		push @aszRegex, [qr/^(.*\s)$szWord(\s.*\s\-\s.*)$/i, ["feat"] ];
	}
	
	return @aszRegex;
}

sub GenNumberWordsRegex
{
	my @aszRegex = ();
	
	foreach my $szLine (  ReadListFile( "./TrackNamerSpecialWords.lst" )  )
	{
		if ($szLine =~ m/^\d/)
		{
			# Worter bei denen zwischen den Bindestrichen Leerzeichen sind genauso behandeln wie ohne
			# und Worter ohne Bindestrich auch
			# 2-4 Grooves => 2\s*\-?\s*4 Grooves
			$szLine =~ s/\-/\\s*\-\?\\s*/g;
			# Worter die mit einer Zahl beginnen auch erkennen wenn ziwschen Zahl und Wort ein Leerzeichen ist
			# 2Elements => 2\s*Elements
			$szLine =~ s/^(\d+)(\D.*)$/$1\\s*$2/g;
			# Worter die ein Abostroph enthalten auch ohne Abostroph erkennen
			# 3 Global Player's => 3 Global Player\'?s
			$szLine =~ s/\'/\\'\?/g;
			
			push @aszRegex, qr/^$szLine/i;
		}
	}
	push @aszRegex, qr/^\d+/i;		# Den eigentlichen Arbeiter-Regex hinzufügen
	
	return [ \@aszRegex, "" ];
}

sub GenSpecialWordsRegex
{
	my @aszRegex = ();
	
	foreach my $szLine (  ReadListFile( "./TrackNamerSpecialWords.lst" )  )
	{
		my $szOldWord = ConvertTrackName(  lc( $szLine ), \@ReplaceWords, 0  );
		push @aszRegex, GetSpecialWordRegex( $szOldWord, $szLine, 1 );
	}
	
	return @aszRegex;
}

sub GenApostropheWordsRegex
{
	my @aszRegex = ();
	
	foreach my $szLine (  ReadListFile( "./TrackNamerSpecialWords.lst" )  )
	{
		my $szOldWord = $szLine;
		$szOldWord =~ s/\'//g;
		push @aszRegex, GetSpecialWordRegex( $szOldWord, $szLine, 1 );
	}
	
	return @aszRegex;
}

sub ReadListFile
{
	my ($szFile) = @_;
	
	my @aszLines = ();
	open(my $hFile, "<$szFile") or die $?;
	while (my $szLine = <$hFile>)
	{
		utf8::decode( $szLine );
		
		chomp($szLine);
	
		if ( ($szLine !~ m/^\s*#/) and ($szLine !~ m/^\s*$/) )
		{
			push @aszLines, $szLine; 
		}
	}
	close($hFile);
	
	return @aszLines;
}

sub GetSpecialWordRegex
{
	my ($szOldWord, $szNewWord, $fInsertSpace) = @_;
	
	
	if ( (defined $fInsertSpace) and ($fInsertSpace == 1) )
	{
		# Nach jedem Buchstaben Leerzeichen einfügen
		$szOldWord =~ s/(.)/$1 /g;
		# Leerzeichen am Ende löschen
		$szOldWord =~ s/\s$//g;
	}
	
	# Bindestrich kann da sein muss er aber nicht
	$szOldWord =~ s/\-/\\-\?/g;
	
	if ( (defined $fInsertSpace) and ($fInsertSpace == 1) )
	{
		# Leerzeichen durch Regex mit Leerzeichen und möglicher Bindestrich ersetzten
		$szOldWord =~ s/\s/\\s*\\-\?\\s*/g;
	}
	
	
	my @aszRegex = ();
	push @aszRegex, [ qr/\s$szOldWord\s/i,		" $szNewWord " ];
	push @aszRegex, [ qr/^$szOldWord\s/i,		"$szNewWord " ];
	push @aszRegex, [ qr/\s$szOldWord$/i,		" $szNewWord" ];
	
	return @aszRegex;
}

1;