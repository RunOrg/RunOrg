All user interaction and social behavior behaves within sites. Sites have both
an identifier and a domain. 

    GET /all?token[,limit,offset]
    
    > 200 { sites: [ { id: <id>, name: <string>, domain: <domain> } ] }
    > 403 <forbidden>

Retrieves all the sites installed on the server, with minor presentation 
information.

Requires a [server administrator](serverAdmin.md) [token](token.md).

    GET /<id>
    GET /<domain>

    > 200 
    { id: <id>, 
      name: <string>, 
      domain? <domain>, 
      picture? <url>, 
      css? <url> }
    > 404 <notFound>

Retrieves basic information about a site and how it should be rendered, using
either its identifier or its domain name.

    PUT /<id>?token
    PUT /<domain>?token

    < { name? <string>, picture? <url|null>, css? <url|null> }
    > 202 { at: <clock>, id: <id> }    
    > 403 { error: "Sites must have a name" }
    > 403 <forbidden>
    > 404 <notFound>

Updates an existing site using either its identifier (recommended) or its
domain. Values which are not provided are not changed, while `null`
values will be set to `null`.

When using the domain form, will create the corresponding site and return
its assigned identifier.  

Requires a [server administrator](serverAdmin.md) [token](token.md) to 
create a new site, or a [site administrator](siteAdmin.md) token to 
update an existing one.

    DELETE /<id>?token
    DELETE /<domain>?token

Deletes a site, making its contents unavailable and freeing up the domain
for another site. Does not erase the site data from the database. 

Requires a [server administrator](serverAdmin.md) [token](token.md).