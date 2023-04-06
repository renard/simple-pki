# -*- Makefile -*-

# Copyright © 2022- Sébastien Gross

# Created: 2022-06-02
# Last changed: 2023-04-06 17:16:22

# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What The Fuck You Want
# To Public License, Version 2, as published by Sam Hocevar. See
# http://sam.zoy.org/wtfpl/COPYING for more details.

## BEGIN HELP
# Generate simple PKI for testing purposes
#
# make ca.pem                         Create a CA certificate
# make test.example.com.pem.rsa       Generate certificate RSA certificate
#                                     for test.example.com.pem
# make test.example.com.pem.ecdsa     Generate certificate ECDSA certificate
#                                     for test.example.com.pem
# make example.com.pem.ecdsa.revoke   Revoke certificate ECDSA certificate
#                                     for test.example.com.pem and generate
#                                     ca.pem.crl revocation list
#
# Additionnal variables:
#
#    DOMAIN       Domain used for the CA (default example.com)
#    DAYS         Certificate validity (default 365)
#    RSA_SIZE     RSA key size (default 4096)
#
# To generate a certificate valid for 5 minutes:
#
#     faketime '-1 day' make ca.pem DOMAIN=example.com
#     faketime '-1 day + 5 minutes' make test.example.com.pem.ecdsa DAYS=1
## END HELP


DOMAIN := example.com
CA_FILE=ca.pem
DAYS := 1

RSA_SIZE := 4096

# Key type. Use "ec" for elliptic cryptography, "rsa" for RSA key.
KEY_TYPE := ec

ifeq ($(KEY_TYPE),ec)
	KEY := -newkey ec -pkeyopt ec_paramgen_curve:prime256v1
else
	KEY := -newkey rsa:$(RSA_SIZE)
endif

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
	OPENSSL := openssl
endif

ifeq ($(UNAME_S),Darwin)
# Use brew version on MacOS which is more up-to-date than the system
# openssl version.
	OPENSSL := $(shell ls /usr/local/Cellar/openssl@1.1/*/bin/openssl | sort -V | tail -n 1)
endif

SHELL := /bin/bash

help:
	@awk '/^## BEGIN HELP/{disp=1;next}/## END HELP/{disp=0}disp' \
		$(lastword $(MAKEFILE_LIST)) | sed 's/^#[[:space:]]\{0,1\}//'


# If SAN is required, add subjectAltName extension:
#     -addext "subjectAltName=DNS:www.example.net,IP:10.0.0.1"
#
$(CA_FILE):
	@$(OPENSSL) req \
		-new -sha256 -nodes \
		$(KEY) \
		-x509 -days $(DAYS) \
		-config <(echo -e  "[req]\ndistinguished_name=dn\n[dn]\n[ext]\nbasicConstraints=critical,CA:true,pathlen:1\nkeyUsage=keyCertSign,cRLSign,digitalSignature,nonRepudiation") \
		-extensions ext \
		-out $@ -keyout $@.key -subj "/CN=ca.$(DOMAIN)"

%.pem.ecdsa:
	@$(MAKE) "$(shell basename $@ .ecdsa)" KEY_TYPE=ec
	@mv "$(shell basename $@ .ecdsa)" $@

%.pem.rsa:
	@$(MAKE) "$(shell basename $@ .rsa)" KEY_TYPE=rsa
	@mv "$(shell basename $@ .rsa)" $@

%.pem: $(CA_FILE)
	@$(OPENSSL) req -new -sha256 -nodes \
		$(KEY) \
		-out $@ -keyout $@.key -subj "/CN=$(shell basename $@ .pem)"

	@$(OPENSSL) x509 -req -in $@ -days $(DAYS)  \
	 	-CA $(CA_FILE) -CAkey $(CA_FILE).key -CAcreateserial \
		-extfile <(echo -e "basicConstraints=critical,CA:false\nextendedKeyUsage=serverAuth,clientAuth\nsubjectAltName=DNS:$(shell basename $@ .pem)")\
	 	-out $@

	@$(OPENSSL) x509 -in $(CA_FILE) >> $@
	@cat $@.key >> $@
	@rm $@.key

	@$(OPENSSL) x509 -pubkey -in $@ -noout | $(OPENSSL) md5
	@$(OPENSSL) pkey -pubout -in $@ | $(OPENSSL) md5

	@$(OPENSSL) verify -CAfile $(CA_FILE) $@


%.pem.rsa.revoke: %.pem.rsa
	@$(MAKE) revoke CERT_FILE="$(shell basename $@ .revoke)" KEY_TYPE=rsa


%.pem.ecdsa.revoke:
	@$(MAKE) revoke CERT_FILE="$(shell basename $@ .revoke)" KEY_TYPE=ec

revoke:
	@touch index.txt
	@$(OPENSSL) ca -cert $(CA_FILE) -keyfile $(CA_FILE).key \
		-config <(echo -e  "[ca]\ndefault_ca=CA\n[CA]\ndatabase=index.txt\ndefault_md=default\n") \
		-updatedb -revoke $(CERT_FILE)
	@$(OPENSSL) ca -cert $(CA_FILE) -keyfile $(CA_FILE).key \
		-config <(echo -e  "[ca]\ndefault_ca=CA\n[CA]\ndatabase=index.txt\ndefault_md=default\n") -gencrl -out $(CA_FILE).crl -crldays 2
	@mv $(CERT_FILE) $(CERT_FILE).revoke
	@$(OPENSSL) crl -in $(CA_FILE).crl -text -noout
	@cat index.txt

clean:
	@rm -rf *.pem *.crl *.key *.pem.ecdsa *.pem.rsa index.txt.* *.revoke
