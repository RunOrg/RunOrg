Concepts / Audience and Access

An **audience** is a data type used to describe an audience—a list of contacts—without 
having to create a dedicated group and keeping it updated. For instance, an audience might specify
_everyone_ and be applicable to all contacts, even those created after the audience itself. Or it
might specify _members of groups A and B_ and be applicable to all contacts in those groups, 
including those added after the audience was created and excluding those removed. 

See the [audience type page](/docs/#/types/audience.js) for a detailed description of audiences as
a data type. 

An **access**, or access level, describes a way in which a contact may interact with a resource,
such as _fill_ a form, _view_ a chatroom or _admin_ a group. These are described for the purpose
of determining whether a certain contact should be granted a certain access. Access levels are 
always short, human-readable lowercase strings like `"fill"`, `"view"` or `"admin"`. 

Most resources allow the client to specify an audience for each access level on that resource. 
These are usually provided as an `audience` field on the resource. 

### Example: form audience
    "audience" : {
      "admin" : { "groups" : [ "board" ] },
      "fill": "anyone"
    },

When reading the resource though a [viewer-dependent](/docs/#/concept/viewer-dependent.md)
API request, it will include an `access` field describing the access levels granted to 
the contact viewing the resource. 

### Example: access levels
    "access" : [ "admin", "fill" ],

Access levels are granted by checking whether the viewing contact belongs to the audience
of that access level, or one of its parent levels. 

Based on the above form audience example:

 - Alice is a database administrator (a member of the special group `/groups/admin`).
   She automatically has full access to all resources: `["admin","fill"]`.

 - Bob is a member of the Board group (`/groups/board`), which makes him an administrator
   of the form. He receives the `admin` access and all its children: `["admin","fill"]`.

 - Charlie is not a member of either group, but he is logged in. The `"anyone"` audience
   grants him only the access to fill the form: `["fill"]`. 

 - 4Chan is not a member of either group, and doesn't even have an associated contact
   in the database. He is not logged in. Still, the `"anyone"` audience also applies to 
   him: `["fill"]`. 

If a viewer does not have any access allowing him to view the resource, he will not get
a response with `[]`: instead, the API will respond with `403 Forbidden`. 


