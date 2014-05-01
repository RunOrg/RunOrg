// DELETE /db/{db}/groups/{id}
// Groups / Delete a group
// 
// Alpha @ 0.1.23
//
// `202 Accepted`, 
// [Delayed](/docs/#/concept/delayed.md).
// [Idempotent](/docs/#/concept/idempotent.md).
//
// Deletes a group forever. The people remain in the database, but their 
// membership (to the deleted group) is forgotten.
//
// ### Response format
//     { "at": <clock> }
// 

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    var id = Query.post(["db/",db,"/groups"],{},auth).id();

    return Query.del(["db/",db,"/groups/",id],auth)
	.assertStatus(202).assertIsJson();

});

// # Examples
// 
// ### Example request
//     DELETE /db/0SNQc00211H/groups/0SNQe0032JZ
// 
// ### Example response
//     202 Accepted
//     Content-Type: application/json 
//     
//     { "at": [[1, 334]] }

TEST("Deleted group disappears.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    
    var id = Query.post(["db/",db,"/groups"],{},auth).id();

    return Query.del(["db/",db,"/groups/",id],auth).then(function() {
	return Query.get(["db/",db,"/groups/",id,"/info"],auth).assertStatus(404);
    });

});

// # Errors
// 
// ## Returns `401 Unauthorized` 
// - ... if the provided token does not allow acting as `{as}`.

TEST("Returns 401 when token is not valid.", function(Query) {
    var db = Query.mkdb();
    return Query.del(["db/",db,"/groups/00000000000"],{id:"01234567890",token:"01234567890"})
	.assertStatus(401);
});

// ## Returns `403 Forbidden` 
// - ... when attempting to delete a group without having **admin** access
//   to that group.

TEST("Returns 403 when deleting group without admin access.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/groups"],{"audience":{"moderate":"anyone"}},auth).id();
    var peon = Query.auth(db,false,"peon@runorg.com")
    return Query.del(["db/",db,"/groups/",id],peon).assertStatus(403);
});

// - ... when attempting to delete group [`admin`](/docs/#/group/admin.md).

TEST("Returns 403 when deleting admin group.", function(Query) {
    var db = Query.mkdb();
    return Query.del(["db/",db,"/groups/admin"]).assertStatus(403);
});

// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.del(["db/00000000000/groups/00000000000"])
	.assertStatus(404);
});

// - ... if group `{id}` does not exist in database `{db}`

TEST("Returns 404 when group does not exist.", function(Query) {
    var db = Query.mkdb();
    return Query.del(["db/",db,"/groups/00000000000"])
	.assertStatus(404);
});

 
// # Access restrictions
//
// Deleting a group requires **admin** [access level](/docs/#/group/audience.js)
// to that group. The [`admin`](/docs/#/group/admin.md) group may not be deleted.
