#/******************************************************************************
#* Copyright (c) 2008, 2015  Ericsson AB
#* All rights reserved. This program and the accompanying materials
#* are made available under the terms of the Eclipse Public License v1.0
#* which accompanies this distribution, and is available at
#* http://www.eclipse.org/legal/epl-v10.html
#*
#* Contributors:
#* Timea Moder
#* Endre Kulcsar
#* Gabor Szalai
#* Janos Kovesdi
#* Kulcsár Endre
#* Zoltan Medve
#* Tamas Korosi
#******************************************************************************/

#                                                                           #
#  File:               ATTR.awk                                             #
#  Description:	       RPMG AWK script for weaving RDF files                #
#  Rev:                R13A
#  Prodnr:             CNL 113 600                                          #
#############################################################################



BEGIN {
      FS = "[ \t\n;]+"
      HT = "  "


      # Number of attribute descriptors found in input RDF file
      attrib_descriptors = 0
      packet_descriptors = 0
      # Number of attribute type definitions matching preceeding attribute descriptor
      matching_attrib_types = 0
      matching_packet_types = 0
      # Identifier of generated TTCN-3 module
      if(!module_id) module_id = "RADIUS_Types"
      # Use APPLICATION-REVISION prefix in Attrib type identifiers when true
      if(!use_application_revision) use_application_revision = 0
      # Replace all enumeration type Attribs with type Unsigned32 when true
      if(!enum_2_UnsignedInt) enum_2_UnsignedInt = 0
      # Generate original structured TTCN-3 code when true
      if(!old_structured_code) old_structured_code = 0
      
    print "module " module_id " {"
}

{ 
	# Remove excess WS from beginning and end of EACH record
	sub(/^[ \t]+/, "") 
	sub(/[ \t]+$/, "")
}

/\/\/ APPLICATION-NAME:/ {
      # Will be used to prefix generated Attribute type definitions
      application_id = $3
}

/\/\/ APPLICATION-REVISION:/ {
  # Could be used as additional prefix for generated ATTR type definitions
  application_revision = $3
  if(use_application_revision && application_revision) {
    application_id = application_id "_" application_revision
  }
}

/\/\/ Packet-Type:/ {
      # Packet descriptor line e.g.:
      # // Packet: Official-Packet-Type (Official-Packet-Code) 
      #            <-------- $3 ------> <------  $4 -------->  
      i = 1
      while ((packet_code[i] != $4) && (i <= packet_descriptors)) {
         i++ 
      }
      if (i > packet_descriptors) {
        new_packet_type = $3
        new_packet_code = $4
        gsub(/-/, "_", new_packet_type)

        packet_descriptors++ 
        ++matching_packet_types
        packet_code[packet_descriptors] = new_packet_code
        packet_type[matching_packet_types] = new_packet_type}
}


/\/\/ Attrib:/ {
      # Attrib descriptor line e.g.:
      # // Attrib: Official-Attrib-Name (Official-Attrib-Code) 
      #            <-------- $3 ------> <------  $4 --------> 
      
      attrib_descriptors++ 
      new_attrib_name = $3
      new_attrib_code = $4
      gsub(/-/, "_", new_attrib_name)
      attrib_desc[new_attrib_name]=new_attrib_name
}

/\<type/ {
	# TTCN-3 type definition e.g.:
	# <type> <kind> <identifier> MUST be in same line!
        if (($3 == new_attrib_name) && (new_attrib_code in ATTR))
        {
          print "// WARNING: Duplicated Attrib definition removed by gawk script!"
          if($2 == "enumerated") { f_ReadTotalEnum() }
          ++deleted_attrib_types
          next
        }
	else if($3 == new_attrib_name) {
                $3 = application_id "_" new_attrib_name
		++matching_attrib_types
                ATTR[new_attrib_code] = new_attrib_name
		attrib_code[matching_attrib_types] = new_attrib_code
		attrib_type[matching_attrib_types] = application_id "_" new_attrib_name
		if($2 == "enumerated") {
		    f_ReadTotalEnum()
                    if(enum_2_UnsignedInt) {
                      print "// WARNING: Enumeration type Attrib replaced by UnsignedInteger!"
                      print "type UINT32 " application_id "_" new_attrib_name ";"
                    }
                    else{
                      prettyprinted_enum = total_enum
		      gsub(/\,/, ",\n", prettyprinted_enum)
		      sub(/\{/, "{\n", prettyprinted_enum)
		      sub(/\}/, "\n}", prettyprinted_enum)
		      f_AddVariant_U32(prettyprinted_enum)
                    }
		} else if ($2 ~ /^enum_[0-9]+$/) {
		    split($2, a, "_")
                    f_ReadTotalEnum()
                    if(enum_2_UnsignedInt) {
                      print "// WARNING: Enumeration type Attrib replaced by UnsignedInteger!"
                      print "type UINT" a[2] " " application_id "_" new_attrib_name ";"
                    }
                    else{
                      prettyprinted_enum = total_enum
		      gsub(/\,/, ",\n", prettyprinted_enum)
		      sub(/\{/, "{\n", prettyprinted_enum)
		      sub(/\}/, "\n}", prettyprinted_enum)
                      gsub(/enum_[0-9]*/, "enumerated ", prettyprinted_enum)
		      f_AddVariant_U(prettyprinted_enum, a[2])
                    }
		}        
          } else if (($2 != "enumerated") && ($2 ~ /^enum_[0-9]+$/)) {
	      split($2, a, "_")
              f_ReadTotalEnum()
              if(enum_2_UnsignedInt) {
                print "// WARNING: Enumeration type Attrib replaced by UnsignedInteger!"
                print "type UINT" a[2]  " " application_id "_" new_attrib_name ";"
              }
              else{
                prettyprinted_enum = total_enum
                gsub(/\,/, ",\n", prettyprinted_enum)
	        sub(/\{/, "{\n", prettyprinted_enum)
	        sub(/\}/, "\n}", prettyprinted_enum)
                gsub(/enum_[0-9]*/, "enumerated ", prettyprinted_enum)
                f_AddVariant_U(prettyprinted_enum, a[2])
              }
	    }    
}

/\/\/ Vendor:/ {
      # Vendor descriptor line e.g.:
      # // Vendor: vendor_name (vendor_id) 
      #            <-- $3 -->   <-- $4 --> 
      
      vendor_name = $3
      gsub(/-/, "_", vendor_name)
      vendor_list[vendor_name]=$4
}

{print}

END {
  print "// STATISTICS: " attrib_descriptors " Attrib descriptors found"
  print "// STATISTICS: " matching_attrib_types \
    " Attrib type definitions matching Attrib descriptors found"
  print "// STATISTICS: " deleted_attrib_types " duplicate Attrib definitions deleted"
  if(attrib_descriptors != matching_attrib_types + deleted_attrib_types) {
    print "// ERROR: attrib_descriptors " attrib_descriptors \
      " != matching_attrib_types " matching_attrib_types
      ss=1
      for(t in attrib_type){
         print ss " " attrib_type[t]
         ss++
      }
      
      ss=1
      print "\n"
      for(t in attrib_desc){
        print ss " " attrib_desc[t]
        ss++
      }

  exit(1)
  }


        
        print "\n"
        
        print "type record Attrib_UNKNOWN"
        print "{"
        print HT "UINT8 attrib_type,"
        print HT "UINT8 attrib_length,"
        print HT "octetstring attrib_value"
        print "} with {"
        print HT " variant (attrib_length) \"LENGTHTO(attrib_type, attrib_length, attrib_value)\""
        print HT "}"
        print "\n"
        
        print "type record vendor_specific_type"
        print "{"
        print HT "vendor_id_enum vendor_id,"
        print HT "string_val_spec attrib_value"
        print "} with {"
        print HT " variant (attrib_value) \"CROSSTAG("
        for(vendor in vendor_list){
          printf (HT HT "f_%s_subattr_list,  vendor_id=%s;\n",vendor, vendor) 
        }
        print HT ")\""
        print "}"
        print "\n"
 
        print "type enumerated vendor_id_enum"
        print "{"
        i=1
        for(vendor in vendor_list){
          if(i==1){
            printf (HT "%s  %s",vendor, vendor_list[vendor]) 
            i++
          } else {
            printf (",\n" HT "%s  %s",vendor, vendor_list[vendor]) 
          }
        }
        print "\n" "} with {"
	      print HT "variant \"FIELDLENGTH(32)\""
	      print HT "variant \"BYTEORDER(last)\""
	      print "}"
        print "\n"

        print "type union string_val_spec"
        print "{"
        i=1
        for(vendor in vendor_list){
          if(i==1){
            printf (HT "%s_subattr_list  f_%s_subattr_list",vendor, vendor) 
            i++
          } else {
            printf (",\n" HT "%s_subattr_list  f_%s_subattr_list",vendor, vendor) 
          }
        }
        print "\n}"
        
        if(old_structured_code){
          for(i = 1; i <= matching_attrib_types; i++) {
            printf("type record Attrib_%s\n", attrib_type[i])
            print "{"
            print HT "Attrib attrib_type,"
            print HT "UINT8 attrib_length,"
            printf(HT "%s %s\n", attrib_type[i], tolower(attrib_type[i])) 
            print "} with {"
            printf(HT " variant \"PRESENCE (attrib_type=%s)\"\n",attrib_type[i])      
            printf(HT " variant (attrib_length) \"LENGTHTO(attrib_type, attrib_length, %s)\"\n",
                      tolower(attrib_type[i]))
            print HT "}"
            print "\n"
          }
        
          print "type set of GenericAttrib Attribs;\n"
        
          print "type union GenericAttrib"
          print "{"
          for(i = 1; i <= matching_attrib_types; i++) {
                printf(HT "Attrib_%s attrib_%s,\n",
                        attrib_type[i],attrib_type[i])  
          }
          print HT "Attrib_UNKNOWN attrib_UNKNOWN"
          print "}\n"
        }
        else{
          print "\n"
          print "type union Attrib_Data"
          print "{"
          for(i = 1; i <= matching_attrib_types; i++) {
            printf(HT "%s %s,\n", attrib_type[i], tolower(attrib_type[i])) 
          }
          print HT "octetstring attrib_UNKNOWN"
          print "}\n"
          
          print "type set of GenAttrib Attribs;\n"
          print "type union GenAttrib"
          print "{"
          print HT "GenericAttrib genericAttrib,"
          print HT "Attrib_UNKNOWN attrib_UNKNOWN"
          print "}\n"
          print "type record GenericAttrib"
          print "{"
          print HT "Attrib attrib_type,"
          print HT "UINT8 attrib_length,"
          print HT "Attrib_Data attrib_data"
          print "} with {"
          print HT " variant (attrib_length) \"LENGTHTO(attrib_type, attrib_length, attrib_data)\""
          print HT " variant (attrib_data) \"CROSSTAG("
          for(i = 1; i <= matching_attrib_types; i++) {
            printf(HT HT "%s,attrib_type=%s;\n", tolower(attrib_type[i]),attrib_type[i]) 
          }
          print HT HT "attrib_UNKNOWN, OTHERWISE"
          print HT ")\""
          print "}"
          print "\n"
        }
        
        print "type enumerated Attrib"
        print HT "{"
        for(i = 1; i <= matching_attrib_types; i++) {
                printf(HT "%s %s%s\n",
                        attrib_type[i], attrib_code[i],
                        (i < matching_attrib_types) ? "," : "")  
        }
        print "} with {"
        print HT "variant \"FIELDLENGTH(8)\""
        print HT "variant \"BYTEORDER(last)\""
        print HT "}\n"
        
                 
        print "type enumerated Code"
        print HT "{"
        for(i = 1; i <= packet_descriptors; i++) {
                printf(HT "%s %s%s\n",
                        packet_type[i], packet_code[i],
                        (i < packet_descriptors) ? "," : "")  
        }
        print "} with {"
        print HT "variant \"FIELDLENGTH(8)\""
        print HT "variant \"BYTEORDER(last)\""
        print HT "}\n"
              

        print "type record PDU_RADIUS"
        print "{"
        print HT "Code code,"
        print HT "UINT8 identifier,"
        print HT "UINT16 message_length,"
        print HT "OCTET16 authenticator,"
        print HT "Attribs attributes"
        print "} with {"
        print HT " variant (message_length) \"LENGTHTO(code, identifier, message_length, authenticator, attributes)\""
        print HT"}\n"
        
        
        print "} with { encode \"RAW\" } // End module"


}

function f_AddVariant_U32(prefix)
{
	print prefix, "with {"
	print HT "variant \"FIELDLENGTH(32)\""
	print HT "variant \"BYTEORDER(last)\""
	print "}"
}

function f_AddVariant_U(prefix,flength)
{
	print prefix, "with {"
	printf(HT "variant \"FIELDLENGTH(%s)\"\n",flength)
	print HT "variant \"BYTEORDER(last)\""
	print "}"
}

function f_ReadTotalEnum()
{
	total_enum = $0
	while(total_enum !~ /\}/) { 
		getline
		sub(/\/\/.*/, "")
		total_enum = total_enum $0
	}	
	# Replace $0 contents with data following } 
	idx = index(total_enum, "}")
	$0 = substr(total_enum, idx+1)
	total_enum = substr(total_enum, 1, idx)
}

