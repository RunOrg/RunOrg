A discussion is a set of comments, represented as an [aspect](aspect.md). 

Discussions carry several [rights](right.md):

 - `view`: to view the discussion (but not its contents).
 - `list`: to view the comments in the discussion
 - `write`: to write new comments to the discussion
 - `moderate`: to delete the comments of others (it is always possible to 
   delete your own comments on discussion you can `view`).
 - `admin`: to change the discussion rights and properties, to delete the 
   discussion.

Discussions may have a `label`, which is intended to be displayed to the 
user. 

## Managing discussions

    GET /<id>/discussion/allWithLabel?token[,limit,offset]

    > 200 { discussions: [ 
      { id: <id>, 
        label: <string>, 
        count: <int>, 
        last: <date> } ] }
    > 403 <forbidden>
    > 404 <notFound>

Queries all groups with a label for which the user has the `view` right.

    GET /<id>/discussion/<id>?token 

    > 200 { label: <string>, count: <int>, last: <date>, rights: [ <right> ] }
    > 404 <notFound>

Queries a discussion for which the user has the `view` right. Includes a 
list of rights available. 
