#!/usr/bin/perl
#
use strict;
use warnings;
use Data::Dumper;

# Types:
# 'Type' => 'schema.TypeBool'
# 'Type' => 'schema.TypeFloat'
# 'Type' => 'schema.TypeInt'
# 'Type' => 'schema.TypeList'
# 'Type' => 'schema.TypeMap'
# 'Type' => 'schema.TypeSet'
# 'Type' => 'schema.TypeString'
sub printParamSnippet {
	my ($snippetsRef,$printfIndent,$paramName,$paramRef,$depth,$isList,$hardcodedTypesRef,$verbose) = @_;
	if($depth > 50){
		print STDERR "Too deep, just avoiding cyclic references. Bye.\n";
		return;
	}
	return if(ref($paramRef) eq 'HASH' && exists($paramRef->{Removed}));
	$isList||=0;
	my %hardcodedTypes = %$hardcodedTypesRef;
	my %snippets = %$snippetsRef;
	my $paramType;
	if(ref($paramRef) eq 'HASH' && exists($paramRef->{Type})){
		$paramType = $paramRef->{Type};
	}else{
		$paramType = $paramName;
	}
	if($paramType eq 'schema.TypeBool'){
		printf(("  "x($depth+1))."%-${printfIndent}s = ",$paramName) if(!$isList);
		print "true|false";
		print "\n" if(!$isList);
	}elsif($paramType eq 'schema.TypeFloat'){
		printf(("  "x($depth+1))."%-${printfIndent}s = ",$paramName) if(!$isList);
		print "1.0";
		print "\n" if(!$isList);
	}elsif($paramType eq 'schema.TypeInt'){
		printf(("  "x($depth+1))."%-${printfIndent}s = ",$paramName) if(!$isList);
		print "1";
		print "\n" if(!$isList);
	}elsif($paramType eq 'schema.TypeSet' || $paramType eq 'schema.TypeList'){
		# Simple struct filled with just "Type" (And our internal Depth)
		if(scalar(keys(%{$paramRef->{Elem}})) == 2 && exists($paramRef->{Elem}->{Type})){ 
			printf(("  "x($depth+1))."%-${printfIndent}s = [",$paramName) if(!$isList);
			printParamSnippet($snippetsRef,
					  $printfIndent+$depth+1,
					  "",
					  $paramRef->{Elem},
					  $depth+1,
					  1,
					  \%hardcodedTypes,
					  $verbose
				 );
		}else{
			print "  "x($depth+1).$paramName." {\n" if(!$isList);
			if(exists($paramRef->{Elem})){
				my $subIndentLevel = 0;
				my $subParam = "";
				my @keysToIterate=();
				if(exists($paramRef->{Elem}->{Order})){
					@keysToIterate=@{$paramRef->{Elem}->{Order}};
				}else{
					@keysToIterate=keys(%{$paramRef->{Elem}});
				}
				foreach $subParam(@keysToIterate){
					$subIndentLevel = length($subParam) if(length($subParam) > $subIndentLevel);
				}
				foreach $subParam(@keysToIterate){
					next if($subParam eq 'Depth' || $subParam eq 'Order');
					printParamSnippet($snippetsRef,
							  $subIndentLevel+$depth+1,
							  $subParam,
							  $paramRef->{Elem}->{$subParam},
							  $depth+1,
							  0,
							  \%hardcodedTypes,
							  $verbose
						 );
				}
			}else{
				print STDERR "No ELEM inside ".Dumper($paramRef);
			}
		}
		if(scalar(keys(%{$paramRef->{Elem}})) == 2 && exists($paramRef->{Elem}->{Type})){
			print "]\n";
		}else{
			print "  "x($depth+1)."}\n";
		}
	}elsif($paramType eq 'schema.TypeMap'){
		print "  "x($depth+1).$paramName." {\n";
		print "  "x($depth+1)."    key = ".'"${var.SOMEVAL}"'."\n";
		print "  "x$depth."  }\n";
	}elsif($paramType  eq 'schema.TypeString'){
		printf(("  "x($depth+1))."%-${printfIndent}s = ",$paramName) if(!$isList);
		print '""';
		print "\n" if(!$isList);
	}else{
		# Try to resolve unknown types.
		if(exists($snippets{$paramType})){
			$paramRef = $snippets{$paramType}{Elem};
			print "Found snippet for $paramType".Dumper($paramRef) if($verbose > 2);
		}elsif(exists($hardcodedTypes{$paramType})){
			$paramRef = $hardcodedTypes{$paramType}{Elem};
			print "Working on hardcoded $paramType\n" if($verbose > 2);
		}elsif(ref($paramRef) eq 'HASH' && exists($paramRef->{Elem})){
			$paramRef = $paramRef->{Elem};
			print "Working on sub-Elem $paramType\n" if($verbose > 2);
		}else{
			print STDERR "Unknown param Type '$paramType' for Param Name: $paramName: ".Dumper($paramRef);
		}
		my $subIndentLevel = 0;
		my $subParam = "";
		my @keysToIterate=();
		if(exists($paramRef->{Order})){
			@keysToIterate=@{$paramRef->{Order}};
		}else{
			@keysToIterate=keys(%{$paramRef});
		}
		my $isNeeded = 0;
		foreach $subParam(@keysToIterate){
			$subIndentLevel = length($subParam) if(length($subParam) > $subIndentLevel);
			if ((exists($paramRef->{$subParam}->{Required})
			     && $paramRef->{$subParam}->{Required} eq 'true'
			    ) ||
			    (exists($paramRef->{$subParam}->{Optional})
			     && $paramRef->{$subParam}->{Optional} eq 'true'
			    ) 
			){
				$isNeeded++;
			}
		}
		return if(!$isNeeded);
		print "  "x($depth+1).$paramName." {\n" if(!$isList);
		foreach $subParam(@keysToIterate){
			next if($subParam eq 'Depth' || $subParam eq 'Order');
			printParamSnippet($snippetsRef,
				  $subIndentLevel+$depth+1,
				  $subParam,
				  $paramRef->{$subParam},
				  $depth+1,
				  0,
				  \%hardcodedTypes,
				  $verbose
			 );
		}
		print "  "x($depth+1)."}\n" if(!$isList);
	}
}
sub getCleanFileContent{
	my ($fileName,$verbose) = @_;
	open(my $fileFH,"<",$fileName) or die("Could not open file: '$fileName'");
	local $/ = undef;
	my $fileContent = <$fileFH>;
	# Remove comments
	$fileContent =~ s#/\*[^*]*\*+([^/*][^*]*\*+)*/|//([^\\]|[^\n][\n]?)*?\n|("(\\.|[^"\\])*"|'(\\.|[^'\\])*'|.[^/"'\\]*)#defined $3 ? $3 : ""#gse;
	# The above regex may remove the new line from // comments
	$fileContent =~ s/{\s*\t/{\n/g;
	close($fileFH);
	my @fileLines = split(/\n/,$fileContent);
	my $lineNum = -1;
	while($lineNum < $#fileLines){
		$lineNum++;
		$fileLines[$lineNum] =~ s/^\s*//g;
		$fileLines[$lineNum] =~ s/\s*$//g;
		print "$fileName"."[".($lineNum+1)."]: ".$fileLines[$lineNum]."\n" if($verbose >= 3);
	}
	return(\@fileLines);
}

# XXX: functions other than main should be traversed and remove this:
my %hardcodedTypes = (
	cloudWatchLoggingOptionsSchema => {
		Type     => 'schema.TypeSet',
		Optional => 'true',
#		Computed => 'true',
		Depth    => 20, # Just fake depths
		Elem     => {
			Depth           => 21,
			enabled         => {
				Type     => 'schema.TypeBool',
				Optional => 'true',
				Depth => 22,
			},
			log_group_name  => {
				Type     => 'schema.TypeString',
				Optional => 'true',
				Depth => 22,
			},
			log_stream_name => {
				Type     => 'schema.TypeString',
				Optional => 'true',
				Depth => 22,
			},
		}
	}
);
my %funcList=();
my %triggerList=();
my $fileList = "./terra.list";
my $verbose = 0;
open(my $fileListFH,"<",$fileList) or die("Could not open ./terra.list");
my %snippets = ();
while(my $currentFile = <$fileListFH>){
	chomp($currentFile);
	my $isInsideComment=0;
	my $preCommentLine="";
	my $mainSchemaDepth=0;
	my ($curParamName,$curSubParamName) = ("","");
	my $funcDepth=0;
	my $parenDepth=0;
	if ($currentFile =~ /_test.go$/
	    || $currentFile !~ /\.go$/
	){
		print "Skip file: $currentFile\n" if ($verbose >= 1);
		next;
	}else{
		print "Work file: $currentFile\n" if ($verbose >= 1);
	}
	my $fileLinesRef = getCleanFileContent($currentFile,$verbose);
	$currentFile =~ s/^.*\/([^\/]*\/[^\/]*)$/$1/;
	my $curFuncName = "";
	my $snippetRef=\%snippets;
	my @paramStack=();
	print "INIT:0 $currentFile "."[$funcDepth]\n" if($verbose >= 1);
	my $curLine = 0;
	foreach my $currentFileLine (@$fileLinesRef){
		$curLine++;
		do {
			my $tempLine = $currentFileLine;
			$tempLine =~ s/\"[^"]*\"//g;
			$tempLine =~ s/\'[^']*\'//g;
			my @lineChars = split(//,$currentFileLine);
			foreach my $curChar(@lineChars){
				$funcDepth++  if($curChar eq '{');
				$funcDepth--  if($curChar eq '}');
				$parenDepth++ if($curChar eq '(');
				$parenDepth-- if($curChar eq ')');
			}
			if($parenDepth > 0){
				print "$currentFile:$curLine"."[$funcDepth] inside parens($parenDepth)\n" if($verbose >= 3);
				next;
			}
		}while($parenDepth > 0);
		if($funcDepth == 0 && $#paramStack > -1){
			@paramStack=();
		}
		if($currentFileLine =~ /^func ([^ ]*)\(.*\).*\*schema/){
			$curFuncName = $1;
			$snippets{$curFuncName}{"Depth"} = $funcDepth; 
			$snippets{$curFuncName}{"Filename"} = $currentFile; 
			push(@paramStack,$snippetRef->{$curFuncName});
			print "$currentFile:$curLine"."[$funcDepth] ^func $curFuncName\n" if($verbose >= 2);
			next;
		}
		next if($#paramStack == -1);
		if($currentFileLine =~ /^\(Schema:|return\) map\[string\]\*schema.Schema\{\}*/){
			print "$currentFile:$curLine"."[$funcDepth] SCHEMA\n" if($verbose >= 2);
			next;
		}
		if($currentFileLine =~ /^Schema: ([a-zA-Z0-9_]*)\(.*\),*/){
			my $refName = $1;
			my $snipPos = $paramStack[$#paramStack];
			$snipPos->{SchemaRef} = $refName;
			print "$currentFile:$curLine"."[$funcDepth] SCHEMA Ref\n" if($verbose >= 2);
			next;
		}
		if($currentFileLine =~ /^\"([^\"]*)\"\s*:\s*([a-zA-Z]*)\(\)/){ #Simple Type
			my($key,$value) = ($1,$2);
			$value =~ s/,$//;
			print "$currentFile:$curLine"."[$funcDepth] S:simplextype K:$key V:$value ".$paramStack[$#paramStack]." \n" if($verbose >= 2);
			my $snipPos = $paramStack[$#paramStack];
			$snipPos->{$key}->{Type} = $value;
			$snipPos->{$key}->{Depth} = $funcDepth+1;
			push(@{$snipPos->{Order}},$key);
			next;
		}
		if($currentFileLine =~ /^"([^"]*)"\s*:\s*\{\}*/
		   || $currentFileLine =~ /\[*"([^"]*)"\]*\s*[:=]\s*&schema.Schema\{\s*$/ #}
		){ #Complex Type
			my $paramName = $1;
			print "$currentFile:$curLine"."[$funcDepth] I:complextype \"$paramName\" stack [{".join('},{',@paramStack)."}]\n" if($verbose >= 2);
			my $snipPos = $paramStack[$#paramStack];
			$snipPos->{$paramName}->{Depth} = $funcDepth;
			push(@paramStack,$snipPos->{$paramName});
			push(@{$snipPos->{Order}},$paramName);
			next;
		}
		if($currentFileLine =~ /^\{*\}\,*$/){ # End complex type.
			my $snipPos = $paramStack[$#paramStack];
			if(!exists($snipPos->{Depth})){
				print Dumper($snipPos);
			}
			print "$currentFile:$curLine"."[$funcDepth] E0:complextype curDepth:".$snipPos->{Depth}." stack [{".join('},{',@paramStack)."}]\n" if($verbose >= 2);
			while($funcDepth < $snipPos->{Depth}){
				pop(@paramStack);
				$snipPos = $paramStack[$#paramStack];
				if($#paramStack == -1){
					print "\tEMPTY stack". Dumper(\%snippets) if ($verbose >= 2);
					last;
				}else{
					print "$currentFile:$curLine"."[$funcDepth] E1:complextype curDepth:".$snipPos->{Depth}.":complextype popped item [{".join('},{',@paramStack)."}]\n" if($verbose >= 2);
				}
			}
			next;
		}
		if($currentFileLine =~ /^(Type|Required|Optional|Computed|Removed|ConflictsWith|Elem)\s*:\s*(.*)\}*,*$/){
			# Elem may be in the same line{TypeString}
			# It may be on a separate line
			# It may be Schema Resource
			# XXX: ConflictsWith can be an array...
			my($key,$value) = ($1,$2);
			$value =~ s/,$//;
			if($key eq "ConflictsWith"){
				$value =~ s/.*\"([^"]*)\".*/$1/;
				print "$currentFile:$curLine"."[$funcDepth] ConflictsWith $value\n" if($verbose >= 2);
			}
			if($key eq "Elem"){
				if($currentFileLine =~ /.*\{*\}.*/){
					# One line sub-struct
					$currentFileLine =~ s/^[^{]*\{(.*)\}\,*/$1/;#}
					if($currentFileLine =~ /^(Type)\s*:\s*(.*)\}*,*$/){
						my $snipPos = $paramStack[$#paramStack];
						$snipPos->{$key}->{$1} = $2;
						$snipPos->{$key}->{Depth} = $funcDepth+1;
						print "$currentFile:$curLine"."[$funcDepth] Elem ref ".$paramStack[$#paramStack]." ".Dumper($snipPos) if($verbose >= 3);
					}else{
						print STDERR "Unknown element items for $currentFileLine";
					}
				}else{
					my $snipPos = $paramStack[$#paramStack];
					$snipPos->{$key}->{Depth} = $funcDepth;
					print "$currentFile:$curLine"."[$funcDepth] Elem ref ".$paramStack[$#paramStack]." ".Dumper($snipPos) if($verbose >= 3);
					push(@paramStack,$snipPos->{$key});
					print "pushed ref ".$paramStack[$#paramStack]." \n" if($verbose >= 2);
				}
			}else{
				my $snipPos = $paramStack[$#paramStack];
				$snipPos->{$key} = $value;
				print "$currentFile:$curLine"."[$funcDepth] K:$key V:$value ref $snipPos".Dumper($snipPos)."\n" if($verbose >= 3);
			}
		}
		if($parenDepth > 0){
			print "Unexpected EOF\n";
		}
	}
}

print Dumper(\%snippets);
exit;
# Generate snippets with this shorcut combos
# [f|s] Full (including optionals) or Short (just the required)
# [main function name] (i.e. resourceAwsInstance)
# # Maybe a short alias can be generated (i.e. "frai" for resourceAwsInstance).
# # What about param orders? We just follow the code-order, this should be wiser than alphabetic.

foreach my $curFunc(sort keys %snippets){
	if(
	      ($curFunc !~ /^resource/ && $curFunc !~ /^dataSource/)
	   || ($curFunc =~ /Schema$/)
	   || (scalar(keys(%{$snippets{$curFunc}})) < 3) # At minimum Depth and Filename
	){
		print "Skipping $curFunc\n" if($verbose > 3);
		next;
	}
	my $abrevFunc = $curFunc;
	$abrevFunc =~ s/^resource/r/g;
	$abrevFunc =~ s/^dataSource/d/g;
	my $fullIndentLevel = -1;
	my $shortIndentLevel = -1;
	my @keysToIterate=();
	# Get the max size of param for indentation.
	if(exists($snippets{$curFunc}{Order})){
		@keysToIterate=@{$snippets{$curFunc}{Order}};
	}else{
		@keysToIterate=keys(%{$snippets{$curFunc}});
	}
	foreach my $curParam(@keysToIterate){
		$fullIndentLevel = length($curParam) if(length($curParam) > $fullIndentLevel);
		if (exists($snippets{$curFunc}{$curParam}{Required})){
			$shortIndentLevel = length($curParam) if(length($curParam) > $shortIndentLevel);
		}
	}
	if($fullIndentLevel == -1){ # No content
		next;
	}
	# print the short (required-only) snippet
	print "snippet s$abrevFunc\n";
	if($curFunc =~ /^dataSource/){
		my $dataName = $curFunc;
		$dataName =~ s/^dataSource(.)(.*)/\l$1$2/g;
		$dataName =~ s/([A-Z])/_\l$1/g;
		print "data \"$dataName\" \"\" {\n"
	}elsif($curFunc =~ /^resource/){
		my $resourceName = $curFunc;
		$resourceName =~ s/^resource(.)(.*)/\l$1$2/g;
		$resourceName =~ s/([A-Z])/_\l$1/g;
		print "resource \"$resourceName\" \"name\" {\n"
	}
	my $depth = 0; # For intra-function recursiveness.
	foreach my $curParam(@keysToIterate){
		if (exists($snippets{$curFunc}{$curParam}{Required}) 
		    && $snippets{$curFunc}{$curParam}{Required} eq 'true'
		){
			printParamSnippet(\%snippets,$shortIndentLevel,$curParam,$snippets{$curFunc}{$curParam},$depth,0,\%hardcodedTypes,$verbose)
		}
	}
	print "}\n";
	print "endsnippet\n\n";
	# Start of full snippet
	print "snippet f$abrevFunc\n";
	if($curFunc =~ /^dataSource/){
		my $dataName = $curFunc;
		$dataName =~ s/^dataSource(.)(.*)/\l$1$2/g;
		$dataName =~ s/([A-Z])/_\l$1/g;
		print "data \"$dataName\" \"name\" {\n"
	}elsif($curFunc =~ /^resource/){
		my $resourceName = $curFunc;
		$resourceName =~ s/^resource(.)(.*)/\l$1$2/g;
		$resourceName =~ s/([A-Z])/_\l$1/g;
		print "resource \"$resourceName\" \"name\" {\n"
	}
	$depth = 0;
	# Required + Optional
	foreach my $curParam(@keysToIterate){
		if (exists($snippets{$curFunc}{$curParam}{Required}) 
		    && $snippets{$curFunc}{$curParam}{Required} eq 'true'
		){
			printParamSnippet(\%snippets,$fullIndentLevel,$curParam,$snippets{$curFunc}{$curParam},$depth,0,\%hardcodedTypes,$verbose)
		}
	}
	$depth = 0;
	foreach my $curParam(@keysToIterate){
		if (exists($snippets{$curFunc}{$curParam}{Optional}) 
		    && $snippets{$curFunc}{$curParam}{Optional} eq 'true'
		){
			printParamSnippet(\%snippets,$fullIndentLevel,$curParam,$snippets{$curFunc}{$curParam},$depth,0,\%hardcodedTypes,$verbose);
		}
	}
	# These not optional or required, maybe only available on data.<something>.whatever.
	foreach my $curParam(@keysToIterate){
		if ((exists($snippets{$curFunc}{$curParam})
		    ) &&
		    (!exists($snippets{$curFunc}{$curParam}{Required})
		     || $snippets{$curFunc}{$curParam}{Required} ne 'true'
		    ) &&
		    (!exists($snippets{$curFunc}{$curParam}{Optional})
		     || $snippets{$curFunc}{$curParam}{Optional} ne 'true'
		    ) &&
		    (!exists($snippets{$curFunc}{$curParam}{Computed})
		     || $snippets{$curFunc}{$curParam}{Computed} ne 'true'
		    )
		){
			printParamSnippet(\%snippets,$fullIndentLevel,$curParam,$snippets{$curFunc}{$curParam},$depth,0,\%hardcodedTypes,$verbose)
		}
	}
	print "}\n";
	print "endsnippet\n\n";
}
print "# vim:ft=snippets:";
