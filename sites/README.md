# Default sites

These are the three websites (or rather, web applications) served directly by
the API server: 

 - `admin`, the administration console available on path `https://domain/admin`
 - `docs`, the online documentation (and unit testing suite) available on path
   `https://domain/docs`
 - `default`, the default interface for accessing a database, available on path
   `https://domain/db/{db}/ui`. 

Each site contains three parts: 

 - The main source code (HTML templates, LESS stylesheets, javascript files and 
   i18n files), which is compiled into...
 - The compiled sources, found in directory `.assets`. 
 - Raw files which are not compiled, found in directory `.static`

The compiled sources are not present in git, use `make` in the site's directory
to create them. 

