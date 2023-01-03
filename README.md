# Simple PKI for testing purposes

This Makefile creates simple PKI for testing purposes. Its main
purpose is to create both server and client certificates to test proxy
SSL offloading.

Do not use for production.


## Usage

Create a self-signed CA:

```
make ca.pem
```

Create a certificate for `server1.example.com`:

```
make server1.example.com.pem.ecdsa
```

If you need a RSA certificate:

```
make server1.example.com.pem.rsa
```

# Help

```
Generate simple PKI for testing purposes

make ca.pem                      Create a CA certificate
make test.example.com.pem.rsa    Generate certificate RSA certificate for
                                 test.example.com.pem
make test.example.com.pem.ecdsa  Generate certificate ECDSA certificate for
                                 test.example.com.pem

Additionnal variables:

   DOMAIN       Domain used for the CA (default example.com)
   DAYS         Certificate validity (default 365)
   RSA_SIZE     RSA key size (default 4096)

To generate a certificate valid for 5 minutes:

    faketime '-1 day' make ca.pem DOMAIN=example.com
    faketime '-1 day + 5 minutes' make test.example.com.pem.ecdsa DAYS=1
```


# Copyright

Copyright © 2022- Sébastien Gross

This program is free software. It comes without any warranty, to the
extent permitted by applicable law. You can redistribute it and/or
modify it under the terms of the Do What The Fuck You Want To Public
License, Version 2, as published by Sam Hocevar. See
http://sam.zoy.org/wtfpl/COPYING for more details.
