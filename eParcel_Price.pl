#!/usr/bin/perl -w
# print_line-v1 - linear style

#----------------oOo----------------
# 09/08/2018
# Added to GitHub repo: eParcel

use Data::Dumper;
use strict; 
use warnings;

my $FieldHeadings = 0;
my $Line = "";

# Note: Allow retreival of parcel dimensions from data file if they are available
my $FromPostcode = 6104; my $ToPostcode;

my $Length = 0; my $Width = 0; my $Height = 0; my $Weight = 0;

my $PostcodeOffset; my $WeightOffset; my $LengthOffset; my $WidthOffset; my $HeightOffset;

my $ConPrice; my $ConGST; my $ConFinalPrice;

my $FRPrice; my $FRGST; my $FRFinalPrice;

my ($TotalFullRateCost, $TotalContractCost, $ParcelSaving, $TotalSaving);
$TotalFullRateCost = 0;
$TotalContractCost = 0;
$ParcelSaving = 0;
$TotalSaving = 0;

my $Result;		#Response from API call
my @Fields;		#Just used to split up the input record

my $Infile;
my $Outfile;
my $reportfile;

$Infile = $ARGV[0];
$Outfile = ">".$Infile;
$reportfile = ">>".$Infile;

open(INFILE, "< $Infile") or die "Can't open $Infile for reading: $!\n";

$Outfile =~ s/(.*)(\..*)/$1_pricing$2/ig;

open(OUTFILE, "$Outfile") ||
    die "cannot open $Outfile: $!";

$reportfile =~ s/(.*)(JOB.*)(\..*)/$1eParcel_REPORT$3/ig;

open(REPFILE, "$reportfile") ||
    die "cannot open $reportfile: $!";


while (<INFILE>) {
	$Line = $_;
	
	chomp($Line);

	if($FieldHeadings == 0){
		#Field headings
		print OUTFILE $Line."\tFull Rate Price (inc GST)\tFull Rate Price (GST)\tFull Rate Price (ex GST)\tContract Price (inc GST)\tContract Price (GST)\tContract Price (ex GST)\tSaving\n";
		$FieldHeadings = 1;
		
		@Fields = split(/\t/, $Line);								#split record line in to separate fields
#		print "\n\nNumber of Headers: $#fields\n\n";
		my $n = 0;
		foreach my $Heading (@Fields) {
			if($Heading =~ /Postcode/i){ $PostcodeOffset = $n;}
			if($Heading =~ /C_CONSIGNEE_POSTCODE/i ){ $PostcodeOffset = $n; $FieldHeadings = 0;}	#If we detect an eParcel formatted file we want to skip the next line also
			if($Heading =~ /Weight/i || $Heading =~ /A_ACTUAL_CUBIC_WEIGHT/i){ $WeightOffset = $n;}
			if($Heading =~ /Length/i || $Heading =~ /A_LENGTH/i){ $LengthOffset = $n;}
			if($Heading =~ /Width/i  || $Heading =~ /A_WIDTH/i){ $WidthOffset = $n;}
			if($Heading =~ /Height/i || $Heading =~ /A_HEIGHT/i){ $HeightOffset = $n;}
			$n++;
		}

		#If we didn't find parcel dimensions in the data file then we need to get the operator to input them
		if(!$WeightOffset){
			print "\nWeight not found. Please enter parcel weight (kg) > ";
			chomp($Weight = <STDIN>);
		}
		
		if(!$HeightOffset){
			print "\nHeight not found. Please enter parcel height (cm) > ";
			chomp($Height = <STDIN>);
			while($Height =~ /\./){
				print "\n* No decimal places allowed *\n\n    Parcel height (cm) > ";
				chomp($Height = <STDIN>);
			}
		}
		
		if(!$LengthOffset){
			print "\nLength not found. Please enter parcel length (cm) > ";
			chomp($Length = <STDIN>);
			while($Length =~ /\./){
				print "\n* No decimal places allowed *\n\n    Parcel length (cm) > ";
				chomp($Length = <STDIN>);
			}
		}
		
		if(!$WidthOffset){
			print "\nWidth not found. Please enter parcel width (cm) > ";
			chomp($Width = <STDIN>);
			while($Width =~ /\./){
				print "\n* No decimal places allowed *\n\n    Parcel width (cm) > ";
				chomp($Width = <STDIN>);
			}
		}
		
	}
	else{
		die "\n\n\n\nNo Postcode field found in data file\n\n\n\n" if !$PostcodeOffset;
		
		if ($Line =~ /\t$/){$Line .= " ";}							#If last field is blank add a space to it
		@Fields = split(/\t/, $Line);								#split record line in to seperate fields
		my $n = 0;
		foreach my $Heading (@Fields) {
			if($n == $PostcodeOffset){ $ToPostcode = $Heading; }
			if($WeightOffset && $n == $WeightOffset){ $Weight = $Heading; }				#Use parcel weight from data if it's available
			if($LengthOffset && $n == $LengthOffset){ $Length = $Heading; }				#Use parcel length from data if it's available
			if($HeightOffset && $n == $HeightOffset){ $Height = $Heading; }				#Use parcel height from data if it's available
			if($WidthOffset  && $n == $WidthOffset) { $Width = $Heading; }				#Use parcel width from data if it's available
			$n++;
		}

		#If postcode has less than 4 digits we need to pad it with zeros eg. 874 becomes 0874
		if($ToPostcode !~ /^[0-9]{4}$/){
			$ToPostcode = sprintf("%04s",$ToPostcode);
		}

		
## Get Full Rate Pricing
		my $Header = "Auth-key:YjQ3NGQzMzctNzUzMy00ZDE5LWE3YjYtYmNhYjk2Mjc5MWFl";
		my $url    = "https://digitalapi.auspost.com.au/postage/parcel/domestic/calculate.{format}?from_postcode=$FromPostcode&to_postcode=$ToPostcode&length=$Length&width=$Width&height=$Height&weight=$Weight&service_code=AUS_PARCEL_REGULAR";
		my $Result = `C:\\apps\\curl\\curl.exe -H "$Header" "$url"`;

		$Result =~ /{(.*)("total_cost":"\d*\.\d*")(.*)/;
		$FRPrice = $2;
		$FRPrice =~ s/"total_cost":"(\d*\.\d*)"/$1/;
		$FRFinalPrice = $FRPrice / 1.1;
		$FRGST = $FRPrice - $FRFinalPrice;


## Get Contract Pricing		
		$Result = "";
		#TEST
		#my $curl_line = qq (-X POST -H "Content-Type: application/json" -H "account-number: 0006258639" -H "Authorization: Basic YThjNmM0YjgtMzg1Ni00MzdjLThhOGItNDc3NDkyNDA5MThlOng2N2I5OGYxYjdiNmZmYzk2YjU1" -d "{\\"from\\":{\\"postcode\\":\\"$FromPostcode\\"},\\"to\\":{\\"postcode\\":\\"$ToPostcode\\"},\\"items\\":[{\\"length\\":\\"$Length\\",\\"width\\":\\"$Width\\",\\"height\\":\\"$Height\\",\\"weight\\":\\"$Weight\\"}]}" "https://digitalapi.auspost.com.au/test/shipping/v1/prices/items");
		#PROD
		my $curl_line = qq (-X POST -H "Content-Type: application/json" -H "account-number: 0006258639" -H "Authorization: Basic YThjNmM0YjgtMzg1Ni00MzdjLThhOGItNDc3NDkyNDA5MThlOng2N2I5OGYxYjdiNmZmYzk2YjU1" -d "{\\"from\\":{\\"postcode\\":\\"$FromPostcode\\"},\\"to\\":{\\"postcode\\":\\"$ToPostcode\\"},\\"items\\":[{\\"length\\":\\"$Length\\",\\"width\\":\\"$Width\\",\\"height\\":\\"$Height\\",\\"weight\\":\\"$Weight\\"}]}" "https://digitalapi.auspost.com.au/shipping/v1/prices/items");
		#my $curl_line = qq (-X POST -H "Content-Type: application/json" -H "account-number: 0006258639" -H "Authorization: Basic YThjNmM0YjgtMzg1Ni00MzdjLThhOGItNDc3NDkyNDA5MThlOng2N2I5OGYxYjdiNmZmYzk2YjU1" -d "{\"from\":{\"postcode\":\"$FromPostcode\"},\"to\":{\"postcode\":\"$ToPostcode\"},\"items\":[{\"length\":\"$Length\",\"width\":\"$Width\",\"height\":\"$Height\",\"weight\":\"$Weight\"}]}" "https://digitalapi.auspost.com.au/shipping/v1/prices/items");
		$Result  = `C:\\apps\\curl\\curl.exe $curl_line`;
		
		if($Result =~ /"errors"/){
			print Dumper $Result;
			die "\n\n*ERROR* Could not get parcel weight. Check parcel specs (eg. Height, Length & Width < 105cm).\n\n";
		}
		
		#Extract price from the results
		$Result =~ /(.*)("product_type":"PARCEL POST \+ SIGNATURE")(.*)("calculated_price":\d*\.\d*)(.*)/;
		$ConPrice = $4;
		$ConPrice =~ s/"calculated_price":(\d*\.\d*)/$1/;

		#Extract the GST
		$Result =~ /(.*)("product_type":"PARCEL POST \+ SIGNATURE")(.*)("calculated_gst":\d*\.\d*)(.*)/;
		$ConGST = $4;
		$ConGST =~ s/"calculated_gst":(\d*\.\d*)/$1/;

		$ConFinalPrice = $ConPrice - $ConGST;

#my ($TotalFullRateCost, $TotalContractCost, $TotalSaving);
		$TotalFullRateCost += $FRFinalPrice;
		$TotalContractCost += $ConFinalPrice;
		$ParcelSaving = $FRFinalPrice - $ConFinalPrice;
		
		#Print out the original fields, unchanged
		$n = 0;
		foreach my $Heading (@Fields) {
			if($n > 0){ print OUTFILE "\t"; }

			if($n == $PostcodeOffset){ print OUTFILE $ToPostcode; }		# Output formatted postcode instead of original
			else{ print OUTFILE $Heading; }

			$n++;
		}

		if($Result =~ /"error"/ || $Result =~ /"errorMessage":/){
			print OUTFILE "\tCould not get price for this article. Check destination postcode is valid and parcel dimensions are within spec.\n";
		}
		else{
			print OUTFILE "\t$FRPrice\t$FRGST\t$FRFinalPrice\t$ConPrice\t$ConGST\t$ConFinalPrice\t$ParcelSaving\n";
		}

	}
	
}

$TotalSaving = $TotalFullRateCost - $TotalContractCost;

print "\n\n\n\n";
printf("Total Full Rate Cost = \$%5.2f",$TotalFullRateCost);
print "\n";
printf("Total Contract Cost = \$%5.2f",$TotalContractCost);
print "\n";
printf("Total Saving = \$%5.2f",$TotalSaving);
print "\n\n\n\n";
if($TotalContractCost > $TotalFullRateCost){
	print "**** WARNING ****\n";
	print "Contract Price is higher than Full Rate price!";
	print "\n\n\n\n";
}


print REPFILE "\n\n--------------------------------------------------";
print REPFILE "\n\n--Stage 2\n--Pricing Summary\n\n\n";
print REPFILE "Input File: $Infile";
printf(REPFILE "\n\nFull Rate Cost = \$%5.2f",$TotalFullRateCost);
printf(REPFILE "\nContract Cost  = \$%5.2f",$TotalContractCost);
printf(REPFILE "\nTotal Saving   = \$%5.2f",$TotalSaving);
printf(REPFILE "\n\n-- All prices exclude GST --\n");

if($TotalContractCost > $TotalFullRateCost){
	print REPFILE "\n\n\n\n**** WARNING ****\n";
	print REPFILE "Contract Price is higher than Full Rate price!";
	print REPFILE "\n\n";
}

close(INFILE);
close(OUTFILE);
close(REPFILE);
