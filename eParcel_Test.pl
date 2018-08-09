#!/usr/bin/perl -w
# print_line-v1 - linear style

#----------------oOo----------------
# 09/08/2018
# Added to GitHub repo: eParcel

$infile = $ARGV[0];
$outfile = ">".$infile;
$reportfile = ">".$infile;

open(INFILE, "< $infile") or die "Can't open $infile for reading: $!\n";

#$outfile =~ s/\.txt/_fixed\.txt/ig;

$outfile =~ s/(.*)(\..*)/$1_checked$2/ig;
$reportfile =~ s/(.*)(JOB.*)(\..*)/$1eParcel_REPORT$3/ig;

open(OUTFILE, "$outfile") ||
    die "cannot open $outfile: $!";

open(REPFILE, "$reportfile") ||
    die "cannot open $reportfile: $!";

my $field_headings = 0;
my $line = "";

my ($num_valid_records, $num_invalid_records, $total_records);

$num_valid_records = 0;
$num_invalid_records = 0;
$total_records = 0;

while (<INFILE>) {
	$line = $_;
	
	chomp($line);

	if($field_headings == 0){
		#Field headings
		print OUTFILE $line."\n";
		$field_headings = 1;
		
		@fields = split(/\t/, $line);								#split record line in to seperate fields
		my $n = 0;
		foreach my $heading (@fields) {
			if( ($heading =~ /Locality/i) || ($heading =~ /C_CONSIGNEE_SUBURB/i) ){ $locality_offset = $n; }
			if( ($heading =~ /State/i) || ($heading =~ /C_CONSIGNEE_STATE_CODE/i) ){    $state_offset = $n; }
			if( ($heading =~ /Postcode/i)  || ($heading =~ /C_CONSIGNEE_POSTCODE/i) ){ $postcode_offset = $n; }
			$n++;
		}
		
	}
	else{

		die "\n\n\n\nNo Locality field found in data file\n\nDo not run eParcel formatted file through this test.\n\n" if !$locality_offset;
		die "\n\n\n\nNo State field found in data file\n\nDo not run eParcel formatted file through this test.\n\n" if !$state_offset;
		die "\n\n\n\nNo Postcode field found in data file\n\nDo not run eParcel formatted file through this test.\n\n" if !$postcode_offset;
		
		if ($line =~ /\t$/){$line .= " ";}							#If last field is blank add a space to it
		@fields = split(/\t/, $line);								#split record line in to seperate fields
		$n = 0;
		foreach my $heading (@fields) {
			if($n == $locality_offset){ $locality = $heading; }
			if($n == $state_offset)   { $state = $heading; }
			if($n == $postcode_offset){ $postcode = $heading; }
			$n++;
		}

		# If postcode has less than 4 digits (AND State = NT) we need to pad it with zeros eg. 874 becomes 0874
		if( ($postcode !~ /^[0-9]{4}$/) && ($state =~ /NT/i) ){
			$postcode = sprintf("%04s",$postcode);
		}
#		print "\n\n\n\n$postcode\n\n\n\n";
		
		$Header = "Authorization: Basic YThjNmM0YjgtMzg1Ni00MzdjLThhOGItNDc3NDkyNDA5MThlOng2N2I5OGYxYjdiNmZmYzk2YjU1";
		$url    = "https://digitalapi.auspost.com.au/shipping/v1/address?suburb=$locality&state=$state&postcode=$postcode";
		$Result = `C:\\apps\\curl\\curl.exe -H "$Header" "$url"`;

#		print "\n\n$Result";

		$n = 0;
		foreach my $heading (@fields) {
			if($n > 0){ print OUTFILE "\t"; }

			if($n == $postcode_offset){ print OUTFILE $postcode; }
			else{ print OUTFILE $heading; }

			$n++;
		}

		if( ($postcode !~ /^[0-9]{4}$/) && ($state !~ /NT/i) ){
			print OUTFILE "\tInvalid\n";
			$num_invalid_records++;
		}
		elsif($Result =~ /"found":false/ || $Result =~ /"errors":/){
			print OUTFILE "\tInvalid\n";
			$num_invalid_records++;
		}
		else{
			print OUTFILE "\n";
			$num_valid_records++;
		}

	}
	
}

print REPFILE "--Stage 1\n--Test Addresses\n";
print REPFILE "\n\nInput File: $infile";
print REPFILE "\n\nValid Records: $num_valid_records";
print REPFILE "\nInvalid Records: $num_invalid_records";

$total_records = $num_valid_records + $num_invalid_records;

print REPFILE "\nTotal Records Processed: $total_records";

if($num_invalid_records > 0){
	print REPFILE "\n\n******** WARNING - INVALID RECORDS FOUND ******";
	print REPFILE "\n********    Check the file & re-test     ******";
}
else{
	print REPFILE "\n\noOo No Errors Found oOo";
}

close(INFILE);
close(OUTFILE);
close(REPFILE);
