# Install

On a development machine, you will need to generate a self-signed certificate.
Use the command: 

    openssl genrsa -des3 -passout pass:test -out key.pem 2048
    openssl req -new -key key.pem -out cert.csr
    openssl x509 -req -days 365 -in cert.csr -signkey key.pem -out cert.pem
    rm cert.csr
