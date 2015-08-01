#!/bin/sh

sed -e  '
s/OPENSSL_DIR = $(TTCN3_DIR)/\OPENSSL_DIR = \/mnt\/TTCN\/Tools\/openssl-0.9.8e/g
s/CPPFLAGS = -D$(PLATFORM) -I$(TTCN3_DIR)\/include/CPPFLAGS = -D$(PLATFORM) -I$(OPENSSL_DIR)\/include -I$(TTCN3_DIR)\/include/g

' \
-e 's/^TTCN3_MODULES =/TTCN3_MODULES = RADIUS_Types.ttcn/g
s/^GENERATED_SOURCES =/GENERATED_SOURCES = RADIUS_Types.cc/g
s/^GENERATED_HEADERS =/GENERATED_HEADERS = RADIUS_Types.hh/g
s/^OBJECTS =/OBJECTS = RADIUS_Types.o/g
/# Add your rules here if necessary./ {
a\
#
a\

a\
AWK=/usr/local/bin/gawk
a\

a\
RADIUS_Types.ttcn: BaseTypes_IETF_RFC2865.rdf Base_IETF_RFC2865.rdf Accounting_IETF_RFC2866_RFC2867.rdf IPv6_IETF_RFC3162.rdf Extensions_IETF_RFC2869.rdf TunnelAuthentication_IETF_RFC2868.rdf DynamicAuthorizationExtensions_IETF_RFC5176.rdf ATTR.awk
a\
	$(AWK) -f ATTR.awk BaseTypes_IETF_RFC2865.rdf Base_IETF_RFC2865.rdf Accounting_IETF_RFC2866_RFC2867.rdf IPv6_IETF_RFC3162.rdf Extensions_IETF_RFC2869.rdf TunnelAuthentication_IETF_RFC2868.rdf DynamicAuthorizationExtensions_IETF_RFC5176.rdf > $@
a\

a\
#
a\
# End of additional rules for RPMG
}
' \
<$1 >$2

