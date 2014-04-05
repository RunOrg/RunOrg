Concepts / Viewer-dependent

A kind of read request.

An API request is **Viewer-dependent** if it must be performed as a 
contact, and the result is different depending on the contact who
performed the request. 

The contact is provided as an additional query parameter called
[`as`](/docs/#/concept/as.md) containing the contact identifier:

     GET /db/0SNQc00211H/forms/0SNQe0032JZ?as=0SNxd0002JZ

If no contact is provided, the request treats the viewer as an 
anonymous internet user, which may in some cases still be granted 
access to the resource. 

RunOrg performs two separate checks when serving a viewer-dependent 
request:

 - Does the provided token allow acting as the contact `as` ? If
   not, `401 Unauthorized` will be returned. 

   Tokens issued by authenticating as a contact allow 
   acting as that contact. A few tokens (depending on the 
   configuration) allow acting as more than one contact: this
   is called _impersonation_. 

 - What data is the contact `as` allowed to see ? 

   If the contact is not allowed to see any data, RunOrg responds with
   `404 Not Found` to ensure [absence
   equivalence](/docs/#/concept/absence-equivalence.md).

   If the response contains a list of items that is dependent on 
   the viewer, then only the items that can be seen by the viewer
   will be included. 

   If the response contains fields with separate access levels, 
   then only the fields that can be seen by the viewer will be 
   included. 

   The exact behavior is always documented for each request. 

