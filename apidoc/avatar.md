An avatar is a [contact](contact.md) that is able to connect to the site. 

    POST /<id>/auth/persona

    < { assertion: <string>, choose? <id> }
    > 200 { token: <token>, id: <id>, profile: <miniProfile> }
    > 200 { choose: <miniProfiles> }
    > 403 { error: "Invalid Persona assertion" }
    
Authenticate on the site using Persona. 

 - If there is currently no contact on the site with the e-mail address
   bound to the Persona account, one is created. The `choose` parameter
   is ignored.
 - If there is one, it is promoted to an avatar, and a [token](token.md) 
   for that avatar is returned. The `choose` parameter is ignored.
 - If there is more than one, and the `choose` parameter is one of them, 
   then that contact is promoted to avatar and a [token](token.md) for 
   it is returned.
 - Otherwise, a list of all matching contacts (and their 
   [mini-profiles](contact.md#mini-profile) is returned. 

On successful authentication, the identifier and 
[mini-profile](contact.md#mini-profile) of the authenticated avatar are 
returned as well.

