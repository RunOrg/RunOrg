A group is a set of [contacts](contact.md) within a [site](site.md). 

Each group carries its own [rights](right.md), namely : 

 - `view`: knowing that the group exists, and how many contacts it 
   contains.
 - `list`: knowing which contacts are within the group, either as a list
    or by querying individual contacts. 
 - `edit`: adding and removing contacts.
 - `delete`: deleting the group

Groups may have a `label`, which is intended to be displayed to the user.
It is expected that only groups with a label can be viewed. 

## Managing groups

    GET /<id>/group/allWithLabel?token[,limit,offset]

    > 200 { groups: [ { id: <id>, label: <string>, count: <int> } ] }
    > 403 <forbidden>
    > 404 <notFound>    

Displays the list of all groups in the [site](site.md) with their labels 
and sizes, sorted by label. Groups without labels are not included.

Requires a [user](user.md) [token](token.md), will issue 403 Forbidden if
missing. Will issue 404 if the [site](site.md) does not exist.

    GET /<id>/group/search?q,token[,limit,offset]

    > 200 { groups: [ { id: <id>, label: <string>, count: <int> } ] }
    > 403 <forbidden>
    > 404 <notFound>

Search for all groups which contain prefix [q] in their label (labels are cut
into individual words beforehand, non-alphabetical characters are not 
considered for comparison). 

Behaves exactly like `allWithLabel` above.

    POST /<id>/group/create?token

    < { label?: <string> }
    > 202 { at: <clock>, id: <id> }
    > 403 <forbidden>
    > 404 <notFound>

    rights: post

Creates a new group and returns its identifier.

    GET /<id>/group/<id>?token

    > 200 { label? <string>, count: <int> }
    > 403 <forbidden>
    > 404 <notFound>

Gets information about a group. Raises 403 if the [token](token.md) does not
match the [site](site.md), and 404 if either the group does not exist or 
the user does not have the `view` right.

    DELETE /<id>/group/<id>?token

    > 202 { at: <clock> }
    > 403 <forbidden>

Deletes a group. Raises 403 if the [token](token.md) does not
match the [site](site.md) or does not have the `delete` right.
If the group does not exist, or the user does not have the `view`
right, nothing happens.

## Group members

    GET /<id>/group/<id>/all?token[,limit,offset]

    > 200 { order: [ <id> ], contacts: { <id>: <miniProfile> } }
    > 403 <forbidden>
    > 404 <notFound>

Queries all members in a group, sorted by 
`COALESCE(lastname, firstname, email, cell)`.

Requires an [user](user.md) [token](token.md). Returns 404 if missing the
`view` right, 403 if missing the `list` right.

    GET /<id>/group/<id>/has/<id*>?token

    > 200 { <id>: true }
    > 403 <forbidden>
    > 404 <notFound>

Returns a dictionary containing the identifiers from the query string
that are present in the group.

Requires an [user](user.md) [token](token.md). Returns 404 if missing the
`view` right, 403 if missing the `list` right.

    POST /<id>/group/<id>/add

    < [ <id> ]

    > 202 { at: <clock> }
    > 403 <forbidden>
    > 404 <notFound>

Adds one or more contacts to the group.

Requires an [user](user.md) [token](token.md). Returns 404 if missing the
`view` right or one of the contacts does not exist, 403 if missing the 
`edit` right.

Contacts already in the group are ignored.

    POST /<id>/group/<id>/add

    < [ <id> ]

    > 202 { at: <clock> }
    > 403 <forbidden>
    > 404 <notFound>

Remove one or more contacts from the group.

Requires an [user](user.md) [token](token.md). Returns 404 if missing the
`view` right or if one of the contacts does not exist, 403 if missing the 
`edit` right.

Contacts not in the group are ignored.

