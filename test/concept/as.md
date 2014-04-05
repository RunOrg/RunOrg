Concepts / Identity

Most API operations are subject to access restrictions: only a select
few [contacts](/docs/#/contact.md) may perform them. The contact who
performed the operation is also stored in most cases and available 
later for an audit log or a "changed by" field. 

This is called the **requester identity**, or just identity. 

# Providing an identity

To specify who is performing the operation, use the additional query
parameter called `as`. In the following example, the request is made
in the name of contact `0SNxd0002JZ`:

     GET /db/0SNQc00211H/forms/0SNQe0032JZ?as=0SNxd0002JZ

Some API operations **require** an identity, and will issue `400 Bad
Request` if it is missing. 

Most operations will work without an identity as long as the access
level for anonymous users allows it. For instance, if a group's
`admin` audience has been set to `"anyone"`, then it becomes possible
to delete the group without an identity. Otherwise, the operation will
fail with `403 Forbidden` or `404 Not Found`.

# Identity dependence

Most API operations have only two possible behaviours: work or abort.
When the provided identity is acceptable (for instance, it has the
required access levels), the operation completes successfully, and
when the provided identity is unacceptable, it fails with `403
Forbidden` or `404 Not Found`.

A few operations wil behave differently based on the identity: these
are said to be [viewer-dependent](/docs/#/concept/viewer-dependent.md). 

# Authentication and authorization

RunOrg performs two separate checks when receiving an `as` parameter:

 - Does the provided token allow acting as the contact `as` ? If
   not, `401 Unauthorized` will be returned. 

   Tokens issued by authenticating as a contact allow 
   acting as that contact. A few tokens (depending on the 
   configuration) allow acting as more than one contact: this
   is called _impersonation_. 

 - Is the contact `as` allowed to perform the operation ? If not, 
   `403 Forbidden` will be returned. 

   If the contact `as` is not even allowed to know that the requested
   resource exists, `404 Not Found` will be used to ensure [absence
   equivalence](/docs/#/concept/absence-equivalence.md).









