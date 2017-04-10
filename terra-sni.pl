#!/usr/bin/perl
#
use strict;
use warnings;
use Data::Dumper;

my %funcList=();
my %triggerList=();
my $fileList = "./terra.list";
my $verbose = 2;
open(my $fileListFH,"<",$fileList) or die("Could not open ./terra.list");
my %snippets = ();
my %snipOrder = ();
while(my $currentFile = <$fileListFH>){
	chomp($currentFile);
	my $mainFuncName = $currentFile;
	my $isInsideComment=0;
	my $preCommentLine="";
	my $mainSchemaDepth=0;
	my ($curParamName,$curSubParamName) = ("","");
	my $funcDepth=-1;
	my $parenDepth=0;
	if ($currentFile =~ /_test.go$/){
		print "Skip file: $currentFile\n" if ($verbose >= 1);
	}else{
		print "Work file: $currentFile\n" if ($verbose >= 1);
	}
	open(my $currentFileFH,"<",$currentFile);
	$currentFile =~ s/^.*\/([^\/]*\/[^\/]*)$/$1/;
	$mainFuncName =~ s/^.*\/([^\/]*).go$/$1/;
	$mainFuncName =~ s/_([a-z])/\U$1/g;
	$snippets{$mainFuncName}{"Depth"} = 0; 
	$snippets{$mainFuncName}{"Filename"} = $currentFile; 
	my $snippetRef=\%snippets;
	my @paramStack=();
	push(@paramStack,$snippetRef->{$mainFuncName});
	print "INIT:0"."[$funcDepth] ".$paramStack[$#paramStack]." \n" if($verbose >= 1);
	while(my $currentFileLine = <$currentFileFH>){
		$currentFileLine =~ s/\/\/.*//g;
		$currentFileLine =~ s/^\s*//g;
		$currentFileLine =~ s/\s*$//g;
		if($currentFileLine =~ /(.*)\/\*/){
			print "$currentFile:$."."[$funcDepth] inside comment\n" if($verbose >= 3);
			$preCommentLine=$1;
			$isInsideComment=1;
			next;
		}
		if($currentFileLine =~ /\*\/(.*)/){
			$currentFileLine=$preCommentLine.$1;
			$preCommentLine="";
			$isInsideComment=0
		}
		do {
			my @lineChars = split(//,$currentFileLine);
			foreach my $curChar(@lineChars){
				$funcDepth++ if($curChar eq '{');
				$funcDepth-- if($curChar eq '}');
				$parenDepth++ if($curChar eq '(');
				$parenDepth-- if($curChar eq ')');
			}
			if($parenDepth > 0){
				print "$currentFile:$."."[$funcDepth] inside parens\n" if($verbose >= 3);
				defined($currentFileLine = <$currentFileFH>) or die("$currentFile:$. Unexpected EOF");
			}
		}while($parenDepth > 0);
		if($currentFileLine =~ /^func ([^ ]*)\(\) \*schema/){
			print "$currentFile:$."."[$funcDepth] ^func $1 (main is $mainFuncName)\n" if($verbose >= 2);
			if($1 eq $mainFuncName){
				$funcDepth = 0;
			}
			next;
		}
		if ($funcDepth < 0){
			next;
		}
		if($currentFileLine =~ /^Schema: map\[string\]\*schema.Schema\{\}*/){
			print "$currentFile:$."."[$funcDepth] SCHEMA\n" if($verbose >= 2);
			next;
		}
		if($currentFileLine =~ /^\"([^\"]*)\"\s*:\s*([a-zA-Z]*)\(\)/){ #Simple Type
			my($key,$value) = ($1,$2);
			$value =~ s/,$//;
			print "$currentFile:$."."[$funcDepth] S:simplextype K:$key V:$value ".$paramStack[$#paramStack]." \n" if($verbose >= 2);
			my $snipPos = $paramStack[$#paramStack];
			$snipPos->{$key}->{Type} = $value;
			push(@{$snipOrder{$mainFuncName}},$key) if($funcDepth == 2); # Top level simple params live in this depth
			# Top level vars live in this depth:
			# function something() *schema.Resource _{_
			# 	return schema.Schema _{_
			#		Schema: ... _{_
			#			"top_level_var":...
			next;
		}
		if($currentFileLine =~ /^"([^"]*)"\s*:\s*\{\}*/){ #Complex Type
			my $paramName = $1;
			print "$currentFile:$."."[$funcDepth] I:complextype \"$paramName\" stack [{".join('},{',@paramStack)."}]\n" if($verbose >= 2);
			my $snipPos = $paramStack[$#paramStack];
			$snipPos->{$paramName}->{Depth} = $funcDepth;
			push(@paramStack,$snipPos->{$paramName});
			push(@{$snipOrder{$mainFuncName}},$paramName) if($funcDepth == 3); # Top level complex param live at this depth:
			next;
		}
		if($currentFileLine =~ /^\{*\}\,*$/){ # End complex type.
			print "$currentFile:$."."[$funcDepth] E0:complextype stack [{".join('},{',@paramStack)."}]\n" if($verbose >= 2);
			my $snipPos = $paramStack[$#paramStack];
			while($funcDepth < $snipPos->{Depth}){
				pop(@paramStack);
				$snipPos = $paramStack[$#paramStack];
				if($#paramStack == -1){
					print "\tEMPTY stack". Dumper(\%snippets) if ($verbose >= 2);
					last;
				}else{
					print "$currentFile:$."."[$funcDepth] E1:complextype popped item [{".join('},{',@paramStack)."}]\n" if($verbose >= 2);
				}
			}
			next;
		}
		if($currentFileLine =~ /^(Type|Required|Optional|Computed|Removed|ConflictsWith|Elem)\s*:\s*(.*)\}*,*$/){
			# Elem may be in the same line{TypeString}
			# It may be on a separate line
			# It may be Schema Resource
			my($key,$value) = ($1,$2);
			$value =~ s/,$//;
			if($key eq "ConflictsWith"){
				$value =~ s/.*\"(.*)\"\,*.*$/$1/;
				print "$currentFile:$."."[$funcDepth] ConflictsWith $value \n" if($verbose >= 2);
			}
			if($key eq "Elem"){
				if($currentFileLine =~ /.*\{*\}.*/){
					# One line sub-struct
					$currentFileLine =~ s/^[^{]*\{(.*)\}\,*/$1/;
					if($currentFileLine =~ /^(Type)\s*:\s*(.*)\}*,*$/){
						my $snipPos = $paramStack[$#paramStack];
						$snipPos->{$key}->{$1} = $2;
						$snipPos->{$key}->{Depth} = $funcDepth+1;
						print "$currentFile:$."."[$funcDepth] Elem ref ".$paramStack[$#paramStack]." ".Dumper($snipPos) if($verbose >= 3);
					}else{
						print STDERR "Unknown element items for $currentFileLine";
					}
				}else{
					my $snipPos = $paramStack[$#paramStack];
					$snipPos->{$key}->{Depth} = $funcDepth;
					print "$currentFile:$."."[$funcDepth] Elem ref ".$paramStack[$#paramStack]." ".Dumper($snipPos) if($verbose >= 3);
					push(@paramStack,$snipPos->{$key});
					print "pushed ref ".$paramStack[$#paramStack]." \n" if($verbose >= 2);
				}
			}else{
				my $snipPos = $paramStack[$#paramStack];
				$snipPos->{$key} = $value;
				print "$currentFile:$."."[$funcDepth] K:$key V:$value ref $snipPos".Dumper($snipPos)."\n" if($verbose >= 3);
			}
		}
		if($funcDepth == 0){
			# finish processing important part.
			last;
		}
	}
	close($currentFileFH);
}
# Generate snippets with this shorcut combos
# [f|s] Full (including optionals) or Short (just the required)
# [main function name] (i.e. resourceAwsInstance)
# # Maybe a short alias can be generated (i.e. "frai" for resourceAwsInstance).
# # What about param orders? We just follow the code-order, this should be wiser than alphabetic.
# Types to XXX:
# 'Type' => 'autoscalingTagsSchema'
# 'Type' => 'cloudWatchLoggingOptionsSchema'
# 'Type' => 'dataSourceFiltersSchema'
# 'Type' => 'dataSourceTagsSchema'
# 'Type' => 'schema.TypeBool'
# 'Type' => 'schema.TypeFloat'
# 'Type' => 'schema.TypeInt'
# 'Type' => 'schema.TypeList'
# 'Type' => 'schema.TypeMap'
# 'Type' => 'schema.TypeSet'
# 'Type' => 'schema.TypeString'
# 'Type' => 'tagsSchema'
# 'Type' => 'tagsSchemaComputed'
# 'Type' => 'vpcPeeringConnectionOptionsSchema'

foreach my $curFunc(keys(%snippets)){
	# Get the max size of param for indentation.
	my $fullIndentLevel = 0;
	my $shortIndentLevel = 0;
	foreach my $curParam(@{$snipOrder{$curFunc}}){
		$fullIndentLevel = length($curParam) if(length($curParam) > $fullIndentLevel);
		if (exists($snippets{$curFunc}{$curParam}{Required})){
			$shortIndentLevel = length($curParam) if(length($curParam) > $shortIndentLevel);
		}
	}
	# print the short (required-only) form 
	print "s$curFunc\n";
	foreach my $curParam(@{$snipOrder{$curFunc}}){
		if (exists($snippets{$curFunc}{$curParam}{Required}) 
		    && $snippets{$curFunc}{$curParam}{Required} eq 'true'
		){
			printf "%{shortIndentLevel}s" $curParam;
			print " = ";
			my $paramType = $snippets{$curFunc}{$curParam}{Type};
			if($paramType eq 'schema.TypeBool'){
				print 'true|false';
			}elsif($paramType eq 'schema.TypeFloat'){
				print '0.00'; # XXX: Find example
			}elsif($paramType eq 'schema.TypeInt'){
				print 'true|false';
			}elsif($paramType eq 'schema.TypeList'){
				print '[]'; # XXX: Difference to TypeSet?
			}elsif($paramType eq 'schema.TypeMap'){
				print '{ key = value}'; # XXX: verify
			}elsif($paramType eq 'schema.TypeSet'){
				print '[]';
			elsif($paramType  eq 'schema.TypeString'){
				print '""';
			}
		}
	}
	# print the optional params
	foreach my $curParam(@{$snipOrder{$curFunc}}){
		print $curParam."\t".Dumper($snippets{$curFunc}{$curParam});
	}
}
