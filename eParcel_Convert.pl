#!/usr/bin/perl -w
# print_line-v1 - linear style


#----------------oOo----------------
# 09/08/2018
# Added to GitHub repo: eParcel


use Data::Dump qw(dump);

####################################################################
my ($infile, $outfile, $errorlog);
my $header_line = 0;
my $input_file_field_headings;
my $line = "";

my $POSTCHARGEACCOUNT = "6258639";
my $CHARGECODE        = "7D55";

# These are fields we read from the data ready file & transform in to fields in the eParcel file
my ($firstname_pos, $lastname_pos, $companyname_pos);
my ($addr1_pos, $addr2_pos, $addr3_pos, $addr4_pos);
my ($loc_pos, $state_pos, $pcode_pos);
my ($df_weight_pos, $df_length_pos, $df_width_pos,$df_height_pos);
my ($label_ref_pos);

# These are fields which are calculated on the fly & output in the eParcel file
my $sort_order;

# These are fields which are manually entered on the command line by the operator
my $job_name;
my $job_number;

#Return Address
my @return_address;

my @parcel;

my @infields;
my $ERROR_REC;

$infile = $ARGV[0];
$outfile = ">".$infile;
$errorlog = $outfile;
open(INFILE, "< $infile") or die "Can't open $infile for reading: $!\n";

$outfile =~ s/(.*)(\..*)/$1_eParcel\.csv/ig;	# Change to .csv
open(OUTFILE, "$outfile") ||
    die "cannot open $outfile: $!";

$errorlog =~ s/(.*)(\..*)/$1_error.log/ig;
open(ERRFILE, "$errorlog") ||
    die "cannot open $errorlog: $!";

&get_job_info_from_user();
	
$sort_order = 0;
while (<INFILE>) {
	chomp($line = $_);

	$ERROR_REC = 0;				#Reset error record check
	@infields = split(/\t/,$line);

	if($header_line == 0){
		$input_file_field_headings = $line;	#Save original field headings in case we need to split off any records to a separate (non-eParcel) file
		#print OUTFILE $line."\n";			# Don't print field headings from the input file
		&print_headings();					# Use the eParcel field names instead
		&print_option_line();
		$header_line = 1;

		my $n = 0;
		foreach my $fieldname (@infields){
			if($fieldname =~ /First Name/i){ $firstname_pos = $n; }
			if($fieldname =~ /Last Name/i){ $lastname_pos = $n; }
			if($fieldname =~ /Company Name/i){ $companyname_pos = $n; }
			if($fieldname =~ /Address Line 1/i){ $addr1_pos = $n; }
			if($fieldname =~ /Address Line 2/i){ $addr2_pos = $n; }
			if($fieldname =~ /Address Line 3/i){ $addr3_pos = $n; }
			if($fieldname =~ /Address Line 4/i){ $addr4_pos = $n; }
			if($fieldname =~ /Locality/i){ $loc_pos = $n; }
			if($fieldname =~ /State/i){ $state_pos = $n; }
			if($fieldname =~ /Postcode/i){ $pcode_pos = $n; }

			if($fieldname =~ /Weight/i){ $df_weight_pos = $n; }
			if($fieldname =~ /Length/i){ $df_length_pos = $n; }
			if($fieldname =~ /Width/i){ $df_width_pos = $n; }
			if($fieldname =~ /Height/i){ $df_height_pos = $n; }

			if($fieldname =~ /Label Ref/i){ $label_ref_pos = $n; }

			$n++;
		}
		
		# Check if we have "first name" and/or "company name" fields in the data
		if (!$firstname_pos){
			if (!$companyname_pos){
				$ERROR_REC = 1;
				#write to error log
				print ERRFILE "The data file has no First Name or Company Name columns";
				die "Error in data file. See log file.  ----------------  ";
			}
			else{
				#make company name our first name
				$firstname_pos = $companyname_pos;
				$companyname_pos = undef;
			}
		}

	}
	else{
		# If there is a separate last name field we need to join it on to the first name. eParcel only as a single "Full Name" field
		# If there is no first name then use the company name as first name
		my $first_name = "";
		my $company_name = "";

		if($firstname_pos){
			$first_name = $infields[$firstname_pos]; 
		}
		
		if($lastname_pos){
			if($first_name ne ""){
				$first_name .= " ".$infields[$lastname_pos];
			}else{
				$first_name = $infields[$lastname_pos];
			}
		}
		
		if($companyname_pos){
			$company_name = $infields[$companyname_pos];
		}
		
		#Warn if any records have a blank first name
		if($first_name ne ""){											# If we have a first name, all good! Print it!
			printf( OUTFILE "%.35s,",$first_name );
			if($company_name ne ""){ 
				printf( OUTFILE "%.35s,",$infields[$companyname_pos] );	# If we also have a company name, print that too!
			}else{
				print OUTFILE ",";										# Else print an empty field. Company Name is optional
			}
		}
		else{
			if($company_name ne ""){									# If first name is empty but company name is not blank
				printf( OUTFILE "%.35s,,",$infields[$companyname_pos] );	# output the company name in the first name column & print an empty field for company name
			}else{
				$ERROR_REC = 1;											# If both first name & company name are empty then the record is invalid.
			}
		}

		# Do we need to get the parcel dimensions from the data file?
		if($dimensions_in_file =~ /Y/i){

			if (!$df_weight_pos){
				$ERROR_REC = 1;
				#write to error log
				print ERRFILE "Could not retrieve parcel dimensions from the data file!";
				die "Error in data file. See log file.  ----------------  ";
			}
			else{
				$parcel[0] = $infields[$df_weight_pos];
				$parcel[1] = $infields[$df_height_pos];
				$parcel[2] = $infields[$df_length_pos];
				$parcel[3] = $infields[$df_width_pos];
				$parcel[4] = ( ($parcel[1]/100) * ($parcel[2]/100) * ($parcel[3]/100) ) * 250; # Cubic weight in kg
			}
		}
		
		if($ERROR_REC == 0){

			if($addr1_pos){ printf( OUTFILE "%.40s,",$infields[$addr1_pos]); }else{ print OUTFILE ",";}			# Print Address Line 1
			if($addr2_pos){ printf( OUTFILE "%.40s,",$infields[$addr2_pos]); }else{ print OUTFILE ",";}			# Print Address Line 2
			if($addr3_pos){ printf( OUTFILE "%.40s,",$infields[$addr3_pos]); }else{ print OUTFILE ",";}			# Print Address Line 3
			if($addr4_pos){ printf( OUTFILE "%.40s,",$infields[$addr4_pos]); }else{ print OUTFILE ",";}			# Print Address Line 4
			if($loc_pos)  { printf( OUTFILE "%.50s,",$infields[$loc_pos]);   }else{ print OUTFILE ",";}			# Print Locality
			if($state_pos){ printf( OUTFILE "%.10s,",$infields[$state_pos]); }else{ print OUTFILE ",";}			# Print State
			if($pcode_pos){ printf( OUTFILE "%.5s,",$infields[$pcode_pos]);  }else{ print OUTFILE ",";}			# Print Postcode
			
			print OUTFILE "AU,";																				# Print Country
			print OUTFILE ",";																					# Phone Number (not used)

			printf( OUTFILE "%.35s,",$return_address[0]);														# Return Address - Name
			printf( OUTFILE "%.40s,",$return_address[1]);														# Return Address - Addr1
			printf( OUTFILE "%.40s,",$return_address[2]);														# Return Address - Addr2
			printf( OUTFILE "%.40s,",$return_address[3]);														# Return Address - Addr3
			printf( OUTFILE "%.40s,",$return_address[4]);														# Return Address - Addr4
			printf( OUTFILE "%.50s,",$return_address[5]);														# Return Address - Locality
			printf( OUTFILE "%.10s,",$return_address[6]);														# Return Address - State
			printf( OUTFILE "%.5s,",$return_address[7]);														# Return Address - Postcode
			print OUTFILE "AU,";																				# Return Address - Country
			print OUTFILE "$parcel[0],";																		# Article - Weight
			print OUTFILE "$parcel[2],";																		# Article - Length
			print OUTFILE "$parcel[3],";																		# Article - Width
			print OUTFILE "$parcel[1],";																		# Article - Height
			print OUTFILE "$POSTCHARGEACCOUNT,";																# Post_Charge_To_Account
			print OUTFILE "$CHARGECODE,";																		# Charge_Code
			print OUTFILE "$job_number - $sort_order,";															# Delivery Instructions - Used to print our reference info on the label
			print OUTFILE "Y,";																					# Signature Required
			print OUTFILE "Job $job_number - Record $sort_order,";												# CRef - Used to print our reference info on the label
			if($label_ref_pos){ printf( OUTFILE "%.50s,",$infields[$label_ref_pos]);  }else{ print OUTFILE ",";} #CRef2 - Read from 'label reference' field in data
			print OUTFILE ",";																					# Goods - Description
			print OUTFILE ",";																					# Consignment - Merchant Consignee Code
			print OUTFILE ",";																					# Consignment - Consigne Email
			print OUTFILE ",";																					# Article - Customs Declared Value
			print OUTFILE ",";																					# Article - Classification Explanation
			print OUTFILE ",";																					# Article - Prod Classification
			print OUTFILE ",";																					# Goods - Origin Country Code
			print OUTFILE ",";																					# Goods - HS Tariff
			print OUTFILE ",";																					# Goods - Quantity
			print OUTFILE ",";																					# Goods - Weight
			print OUTFILE ",";																					# Goods - Unit Value
			print OUTFILE ",";																					# Goods - Total Value
		}
		print OUTFILE "\n";

		if( $ERROR_REC != 0 ){
			print ERRFILE "Record $sort_order has no First Name or Company Name";
			die "Error in record $sort_order. See log file.  ----------------  ";
		}
		
	}
	
		$sort_order++;				#Increment sort order
}


close(INFILE);
close(OUTFILE);


sub get_job_info_from_user{

	my $need_return_addr;
	my $num_items;
	my ($weight, $length, $width, $height);
	my ($t_weight, $t_length, $t_width, $t_height);

	
	# We don't actually need to save the individual item stats at the moment, but when
	# we move to a GUI this is where the values from the text entry fields will be stored
	# & the total parcel specs calculated later

	#Items in parcel
	my (@item1, @item2, @item3, @item4, @item5, @item6);
	
	print "\n\n\nJob Name > ";
	chomp($job_name = <STDIN>);

	print "\n\nJob Number > ";
	chomp($job_number = <STDIN>);
	while($job_number !~ /^[0-9]{6}$/){					#Match exactly 6 digits
		print "\nPlease enter a valid Job Number > ";
		chomp($job_number = <STDIN>);
	}

	@return_address = ("","","","","","","","");
	$need_return_addr = "N";
	print "\n\nDo you want to change return address? (Default - Mailing Solutions, 30 Hargreaves etc.) (Y|N) > ";
	chomp($need_return_addr = <STDIN>);
	if($need_return_addr =~ /Y/i){
		#Get return details
		print "Return Name > ";      chomp($return_address[0] = <STDIN>);
		print "Return Address 1 > "; chomp($return_address[1] = <STDIN>);
		print "Return Address 2 > "; chomp($return_address[2] = <STDIN>);
		print "Return Address 3 > "; chomp($return_address[3] = <STDIN>);
		print "Return Address 4 > "; chomp($return_address[4] = <STDIN>);
		print "Return Locality > ";  chomp($return_address[5] = <STDIN>);
		print "Return State > ";     chomp($return_address[6] = <STDIN>);
		print "Return Postcode > ";  chomp($return_address[7] = <STDIN>);
	}else{
		$return_address[0] = "Mailing Solutions";
		$return_address[1] = "30 Hargreaves Street";
		$return_address[2] = "";
		$return_address[3] = "";
		$return_address[4] = "";
		$return_address[5] = "BELMONT";
		$return_address[6] = "WA";
		$return_address[7] = "6104";
	}

	
	
###################################################################
#
# Use this if you want to enter the dimensions of the individual
# items rather than the final finished parcel
#	
	# print "\n\nHow many items are in each parcel (1-5) > ";
	# chomp($num_items = <STDIN>);
	# while($num_items !~ /^[1|2|3|4|5]{1}$/){
		# print "\nNumber of items must be between 1 and 5 > ";
		# chomp($num_items = <STDIN>);
	# }

	# my $n = 1;
	# while($n <= $num_items){
		# print "\n    Item $n weight (kg) > ";
		# chomp($weight = <STDIN>);
		# if   ($n == 1){ $item1[0] = $weight; $t_weight += $weight }
		# elsif($n == 2){ $item2[0] = $weight; $t_weight += $weight }
		# elsif($n == 3){ $item3[0] = $weight; $t_weight += $weight }
		# elsif($n == 4){ $item4[0] = $weight; $t_weight += $weight }
		# elsif($n == 5){ $item5[0] = $weight; $t_weight += $weight }

		# print "\n    Item $n height (cm) > ";
		# chomp($height = <STDIN>);
		# while($height =~ /\./){
			# print "\n* No decimal places allowed *\n\n    Item $n height (cm) > ";
			# chomp($height = <STDIN>);
		# }
		# if   ($n == 1){ $item1[1] = $height; $t_height += $height }
		# elsif($n == 2){ $item2[1] = $height; $t_height += $height }
		# elsif($n == 3){ $item3[1] = $height; $t_height += $height }
		# elsif($n == 4){ $item4[1] = $height; $t_height += $height }
		# elsif($n == 5){ $item5[1] = $height; $t_height += $height }

		# print "\n    Item $n length (cm) > ";
		# chomp($length = <STDIN>);
		# while($length =~ /\./){
			# print "\n* No decimal places allowed *\n\n    Item $n length (cm) > ";
			# chomp($length = <STDIN>);
		# }
		# if   ($n == 1){ $item1[2] = $length; $t_length += $length }
		# elsif($n == 2){ $item2[2] = $length; $t_length += $length }
		# elsif($n == 3){ $item3[2] = $length; $t_length += $length }
		# elsif($n == 4){ $item4[2] = $length; $t_length += $length }
		# elsif($n == 5){ $item5[2] = $length; $t_length += $length }

		# print "\n    Item $n width (cm) > ";
		# chomp($width = <STDIN>);
		# while($width =~ /\./){
			# print "\n* No decimal places allowed *\n\n    Item $n width (cm) > ";
			# chomp($width = <STDIN>);
		# }
		# if   ($n == 1){ $item1[3] = $width; $t_width += $width }
		# elsif($n == 2){ $item2[3] = $width; $t_width += $width }
		# elsif($n == 3){ $item3[3] = $width; $t_width += $width }
		# elsif($n == 4){ $item4[3] = $width; $t_width += $width }
		# elsif($n == 5){ $item5[3] = $width; $t_width += $width }

		# print "\n------------------------------\n";

		# $n++;
	# }
	
	# #Cubic weight = height x length x width x 250 (Note: dimensions are in metres)
	# #Actual weight = Item 1 weight +  Item 2 weight + Item 3 weight + Item 4 weight + Item 5 weight

	# $parcel[0] = $t_weight; # Weight in kg
	# $parcel[1] = $t_height; # Height in cm
	# $parcel[2] = $t_length; # length in cm
	# $parcel[3] = $t_width;  # width in cm
	# $parcel[4] = ( ($parcel[1]/100) * ($parcel[2]/100) * ($parcel[3]/100) ) * 250; # Cubic weight in kg

	
	
###################################################################
#
# Use this if you want to enter the dimensions of the actual
# parcel rather than the individual items
#	

	$dimensions_in_file = "Y";
	print "\n\nAre the parcel dimensions (weight, len, width, height) in the data file (Y|N) > ";
	chomp($dimensions_in_file = <STDIN>);
	if($dimensions_in_file =~ /N/i){

		print "\n    Total parcel weight (kg) > ";
		chomp($weight = <STDIN>);

		print "\n    Parcel height (cm) > ";
		chomp($height = <STDIN>);
		while($height =~ /\./){
			print "\n* No decimal places allowed *\n\n    Parcel height (cm) > ";
			chomp($height = <STDIN>);
		}

		print "\n    Parcel length (cm) > ";
		chomp($length = <STDIN>);
		while($length =~ /\./){
			print "\n* No decimal places allowed *\n\n    Parcel length (cm) > ";
			chomp($length = <STDIN>);
		}

		print "\n    Parcel width (cm) > ";
		chomp($width = <STDIN>);
		while($width =~ /\./){
			print "\n* No decimal places allowed *\n\n    Parcel width (cm) > ";
			chomp($width = <STDIN>);
		}

		$parcel[0] = $weight;
		$parcel[1] = $height;
		$parcel[2] = $length;
		$parcel[3] = $width;
		$parcel[4] = ( ($parcel[1]/100) * ($parcel[2]/100) * ($parcel[3]/100) ) * 250; # Cubic weight in kg
	}
	
#	print "\nThe cubic weight is " . $parcel[4] . "kg";
#	print "\nTotal actual weight is " . $parcel[0] . "kg";
#	print "\nTotal height is " . $parcel[1] . "cm";
#	print "\nTotal length is " . $parcel[2] . "cm";
#	print "\nTotal width is " . $parcel[3] . "cm";
	
}







# This is the current eParcel data upload file format
sub print_headings{
	my @field_headings = qw(
		C_CONSIGNEE_NAME						
		C_CONSIGNEE_BUSINESS_NAME				
		C_CONSIGNEE_ADDRESS_1					
		C_CONSIGNEE_ADDRESS_2					
		C_CONSIGNEE_ADDRESS_3					
		C_CONSIGNEE_ADDRESS_4					
		C_CONSIGNEE_SUBURB						
		C_CONSIGNEE_STATE_CODE					
		C_CONSIGNEE_POSTCODE					
		C_CONSIGNEE_COUNTRY_CODE				
		C_CONSIGNEE_PHONE_NUMBER				
		C_RETURN_NAME							
		C_RETURN_ADDRESS_1						
		C_RETURN_ADDRESS_2						
		C_RETURN_ADDRESS_3						
		C_RETURN_ADDRESS_4						
		C_RETURN_SUBURB							
		C_RETURN_STATE_CODE						
		C_RETURN_POSTCODE						
		C_RETURN_COUNTRY_CODE					
		A_ACTUAL_CUBIC_WEIGHT					
		A_LENGTH								
		A_WIDTH									
		A_HEIGHT								
		C_POST_CHARGE_TO_ACCOUNT				
		C_CHARGE_CODE							
		C_DELIVERY_INSTRUCTION					
		C_SIGNATURE_REQUIRED					
		C_REF									
		C_REF2									
		G_DESCRIPTION							
		C_MERCHANT_CONSIGNEE_CODE				
		C_CONSIGNEE_EMAIL						
		A_CUSTOMS_DECLARED_VALUE				
		A_CLASSIFICATION_EXPLANATION			
		A_PROD_CLASSIFICATION					
		G_ORIGIN_COUNTRY_CODE					
		G_HS_TARIFF								
		G_QUANTITY								
		G_WEIGHT								
		G_UNIT_VALUE							
		G_TOTAL_VALUE							
	);
	
	my $last = $#field_headings;		# Get index of last array
	foreach my $n (@field_headings) {
		print OUTFILE $n;
		if($last--){
			print OUTFILE ",";			# Don't put a comma after the last element
		}
	}
	print OUTFILE "\n";
}


# This is a mandatory line in the upload file that describes whether a field is mandatory or optional.
# Why this is necessary in every file I don't know. Your guess is as  good as mine.
sub print_option_line{
	print OUTFILE "MANDATORY/OPTIONAL REFER TO GUIDE,";
	print OUTFILE "OPTIONAL,";
	print OUTFILE "MANDATORY/OPTIONAL REFER TO GUIDE,";
	print OUTFILE "OPTIONAL,";
	print OUTFILE "OPTIONAL,";
	print OUTFILE "OPTIONAL,";
	print OUTFILE "MANDATORY/OPTIONAL REFER TO GUIDE,";
	print OUTFILE "MANDATORY/OPTIONAL REFER TO GUIDE,";
	print OUTFILE "MANDATORY/OPTIONAL REFER TO GUIDE,";
	print OUTFILE "MANDATORY/OPTIONAL REFER TO GUIDE,";
	print OUTFILE "MANDATORY/OPTIONAL REFER TO GUIDE,";
	print OUTFILE "OPTIONAL,";
	print OUTFILE "OPTIONAL,";
	print OUTFILE "OPTIONAL,";
	print OUTFILE "OPTIONAL,";
	print OUTFILE "OPTIONAL,";
	print OUTFILE "OPTIONAL,";
	print OUTFILE "OPTIONAL,";
	print OUTFILE "OPTIONAL,";
	print OUTFILE "OPTIONAL,";
	print OUTFILE "MANDATORY,";
	print OUTFILE "MANDATORY/OPTIONAL REFER TO GUIDE,";
	print OUTFILE "MANDATORY/OPTIONAL REFER TO GUIDE,";
	print OUTFILE "MANDATORY/OPTIONAL REFER TO GUIDE,";
	print OUTFILE "OPTIONAL,";
	print OUTFILE "MANDATORY,";
	print OUTFILE "OPTIONAL,";
	print OUTFILE "OPTIONAL,";
	print OUTFILE "OPTIONAL,";
	print OUTFILE "OPTIONAL,";
	print OUTFILE "MANDATORY,";
	print OUTFILE "MANDATORY/OPTIONAL REFER TO GUIDE,";
	print OUTFILE "MANDATORY/OPTIONAL REFER TO GUIDE,";
	print OUTFILE "MANDATORY/OPTIONAL REFER TO GUIDE,";
	print OUTFILE "MANDATORY/OPTIONAL REFER TO GUIDE,";
	print OUTFILE "MANDATORY/OPTIONAL REFER TO GUIDE,";
	print OUTFILE "MANDATORY/OPTIONAL REFER TO GUIDE,";
	print OUTFILE "MANDATORY/OPTIONAL REFER TO GUIDE,";
	print OUTFILE "MANDATORY/OPTIONAL REFER TO GUIDE,";
	print OUTFILE "MANDATORY/OPTIONAL REFER TO GUIDE,";
	print OUTFILE "MANDATORY/OPTIONAL REFER TO GUIDE,";
	print OUTFILE "MANDATORY/OPTIONAL REFER TO GUIDE\n";
}






###################################################################
#
# Addendum
#
# eParcel upload file format

#		Field NAme								Index	MAx Length		Description
#
#		C_CONSIGNEE_NAME						# 0		35				First Name (if blank move company name in to this field)
#		C_CONSIGNEE_BUSINESS_NAME				# 1		35				Company Name
#		C_CONSIGNEE_ADDRESS_1					# 2		40				Address Line 1
#		C_CONSIGNEE_ADDRESS_2					# 3		40				Address Line 2
#		C_CONSIGNEE_ADDRESS_3					# 4		40				Address Line 3
#		C_CONSIGNEE_ADDRESS_4					# 5		40				Address Line 4
#		C_CONSIGNEE_SUBURB						# 6		50				Locality
#		C_CONSIGNEE_STATE_CODE					# 7		10				State
#		C_CONSIGNEE_POSTCODE					# 8		5				Postcode
#		C_CONSIGNEE_COUNTRY_CODE				# 9		30
#		C_CONSIGNEE_PHONE_NUMBER				# 10
#		C_RETURN_NAME							# 11	35
#		C_RETURN_ADDRESS_1						# 12	40
#		C_RETURN_ADDRESS_2						# 13	40
#		C_RETURN_ADDRESS_3						# 14	40
#		C_RETURN_ADDRESS_4						# 15	40
#		C_RETURN_SUBURB							# 16	50
#		C_RETURN_STATE_CODE						# 17	10
#		C_RETURN_POSTCODE						# 18	5
#		C_RETURN_COUNTRY_CODE					# 19	30
#		A_ACTUAL_CUBIC_WEIGHT					# 20	6.2
#		A_LENGTH								# 21	INT
#		A_WIDTH									# 22	INT
#		A_HEIGHT								# 23	INT
#		C_POST_CHARGE_TO_ACCOUNT				# 24	
#		C_CHARGE_CODE							# 25	
#		C_DELIVERY_INSTRUCTION					# 26	
#		C_SIGNATURE_REQUIRED					# 27	
#		C_REF									# 28	50
#		C_REF2									# 28	50
#		G_DESCRIPTION							# 29	
#		C_MERCHANT_CONSIGNEE_CODE				# 30	
#		C_CONSIGNEE_EMAIL						# 31	
#		A_CUSTOMS_DECLARED_VALUE				# 32	
#		A_CLASSIFICATION_EXPLANATION			# 33	
#		A_PROD_CLASSIFICATION					# 34	
#		G_ORIGIN_COUNTRY_CODE					# 35	
#		G_HS_TARIFF								# 36	
#		G_QUANTITY								# 37	
#		G_WEIGHT								# 38	
#		G_UNIT_VALUE							# 39	
#		G_TOTAL_VALUE							# 40
