Concepts / Absence equivalence

A fundamental principle of the RunOrg API, when dealing with access 
restrictions, is that there should be no difference between a resource
that does not exist and a resource that cannot be viewed. 

In other words, the API never responds with _"this resource exists but
you cannot view it"_: it will respond _"this resource does not exist"_ 
instead. 

In HTTP terms, this means a `GET` request will: 

 - Receive a `200 OK` response if the resource is viewable.
 - Receive a `404 Not Found` response if the resource does not exist.
 - Receive a `404 Not Found` response if the resource exists but 
   cannot be viewed by the contact requesting it. 
 - Receive a `401 Unauthorized` response if the authorization token
   does not match the `as` query parameter (see [viewer 
   dependence](/docs/#/concept/viewer-dependent.md)).
 - Never receive a `403 Forbidden` under any circumstances.

Other requests (`POST`, `PUT` and `DELETE`) may fail with 
a `403 Forbidden` if the requester does not have the access level 
required to perform that operation (such as updating a resource 
without the **update** access level), but will also return 
`404 Not Found` if the resource cannot be viewed. 

Note that this restriction is not foolproof, and there are edge cases
where an user may still be able to discriminate between missing
resources and hidden resources:

 - If the resource is identified by a [custom identifier](/docs/#/types/custom-id.js),
   and the user can create resources of that type, then they may try to create a 
   resource with that identifier and receive a telltale `409 Conflict` revealing
   the existence of the resource.

 - On average, a `404 Not Found` response will take a few microseconds longer 
   when the resource exists but is hidden. By performing the request a large
   number of times, an attacker may determine the existence of a resource 
   through statical analysis of the response times. 

