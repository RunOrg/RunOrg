Contacts are information about people related to the site:
administrators, users, newsletter readers... They serve as the 
fundamental atom of information about a person.

The *name* of a contact is just a clean visible representation of the
person: it could be a pseudonym (`Picasso`), a firstname-lastname pair
(`Pablo Ruiz`), the initial segment of an e-mail address
(`pablo.ruiz@...`) or any other short representation chosen by the
server for that contact.

    GET /<id>/contact/all?token[,limit,offset]

    > 200 { <id>: { name: <string>, pic? <url> } ] }
    > 403 <forbidden>
    > 404 <notFound>

    rights: get

Retrieves all contacts of the specified [site](site.md). Requires a 
[site avatar](siteAdmin.md) [token](token.md) with the `get` 
[right](right.md).

    GET /<id>/contact/<id>?token
    
    > 200 
    { name: <string>, 
      firstname? <string>, 
      lastname? <string>, 
      pic? <url>, 
      email? [ <email> ],
      cell? [ <phone> ] }
    > 404 <notFound>
    > 403 <forbidden>

    rights: get, email, cell

Retrieves information about a contact based on its identifier. If no such 
contact exists, or the provided [token](token.md) does not grant viewing 
access to the contact, a 404 Not Found is returned. 

Access rules may limit the returned fields. For instance, only specific 
rights may view the email address of contacts. The corresponding 
[rights](right.md) are:

 - `get`: the ability to receive any data at all
 - `email`: viewing the email of a contact
 - `cell`: viewing the cell phone number of a contact

A contact may always view their own full profile, regardless of rights. 

Requires an [avatar](avatar.md) [token](token.md).

<a name="mini-profile"></a>

    GET /<id>/contact/<id*>/short?token

    > 200 { <id>: { name: <string>, pic? <url> } }
    
Grabs the **mini-profile** (shortened contact information) for one or
more contacts. The returned fields `name` and `pic` are the same as
the non-short version above.

Uses the same [right](right.md) `get` as the non-short version.

Requires an [avatar](avatar.md) [token](token.md).

    POST /<id>/contact/create?token

    < 
    [ { firstname? <string>, 
      lastname? <string>, 
      email? [ <email> ], 
      pic? <url>,
      cell? [ <phone> } ] ]

    > 202 { at: <clock>, id: [ <id> ] }
    > 403 <forbidden>
    > 403 { error: "Please provide last name, email or cell number." }

    rights: post

Creates one or more new contacts. At least one field among `lastname`, 
`email` and `cell` is required for each one of them. 

Requires an [user](user.md) [token](token.md) with the `post` 
[right](right.md).

    PUT /<id>/contact/<id>?token

    <
    { firstname? <string>,
      lastname? <string>, 
      email? [ <email> ],
      pic? <url>, 
      cell? [ <cell> ] }

    > 202 { at: <clock> }
    > 404 <notFound>
    > 403 <forbidden>

    rights: put

Updates the information about an _existing_ contact. Missing fields are
not updated. 

Token must have the `put` [right](right.md) or own the contact. 

Requires an [user](user.md) [token](token.md). 
