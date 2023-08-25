#!/bin/bash
keytool-importkeypair -p android -alias platform -k ./platform.keystore -pk8 ./platform.pk8 -cert ./platform.x509.pem
