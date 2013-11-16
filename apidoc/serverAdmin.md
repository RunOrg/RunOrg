Server administrators have full administrator power at server level. 

    GET /admin/all?token

    > 200 { admins: [ { email: <string> } ] }
    > 403 <forbidden>

Retrieves the list of all server administrators. 

    GET /admin/{email}?token

    > 200 { email: <string>, since: <date|null>, fromConfig: <bool> }
    > 404 <notFound>
    > 403 <forbidden>

Administrators which were loaded from the configuration file (as opposed to 
being present in the database) may have a 'since' date of NULL.

Requires a server administrator [token](token.md).

    DELETE /admin/{email}?token

    > 202 { at: <clock> }   
    > 404 <notFound>
    > 403 <forbidden>
    > 405 { error: "Cannot delete fromConfig admins" }

Idempotent deletion operator: deletes an administrator even if it does not
exist. If the administrator is defined from a configuration file (even if
it was also created from the API), HTTP 405 is returned and the administrator
remains.

Requires a server administrator [token](token.md).

    PUT /admin/{email}?token 

    < {}

    > 202 { at: <clock> }
    > 403 <forbidden> 

Idempotent creation operator: creates an administrator, does nothing if it
already exists. 	   

Requires a server administrator [token](token.md).

    POST /admin/auth/persona

    < { assertion: <string> }

    > 200 { token: <token> }
    > 403 { error: "Invalid Persona assertion" }
    > 403 { error: "Not an administrator" }
    
Attempts to authenticate using a Persona assertion. The audience should be 
the domain of the API interface (set through the configuration as 
`api_interface_domain`). 
