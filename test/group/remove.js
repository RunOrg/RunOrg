// POST /db/{db}/groups/{id}/remove
// Groups / Remove members from a group
// 
// Alpha @ 0.1.23
//
// `202 Accepted`,
// [Delayed](/docs/#/concept/delayed.md),
// [Idempotent](/docs/#/concept/idempotent.md).
//
// Removes the provided members from the specified group. People not 
// in the group (or who do not exist) are silently ignored. 
// 
// ### Request format
//     [ <id>, ... ]
//
// The removed members are passed as an array of identifiers. 

TEST("The response has valid return code and content type.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.post(["db/",db,"/groups/admin/remove"],[peon.id],auth)
	.assertStatus(202).assertIsJson();    
});

TEST("An empty list is acceptable.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.post(["db/",db,"/groups/admin/remove"],[],auth)
	.assertStatus(202);    
});

TEST("Duplicate contacts in list are acceptable.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.post(["db/",db,"/groups/admin/remove"],[peon.id,peon.id],auth)
	.assertStatus(202);    
});

TEST("Removed contacts can not be found in the group.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var peon = Query.auth(db,true,"peon@runorg.com");
    return Query.post(["db/",db,"/groups/admin/remove"],[peon.id],auth).then(function() {
	return Query.get(["db/",db,"/groups/admin"],auth).then(function(d,s,r) { 
	    var list = d.list;
	    return $.when(
		Assert.areEqual(1,list.length),
		Assert.areEqual(auth.id, list[0].id)
	    );
	});
    });
});

// # Examples
// 
// ### Example request
//     POST /db/0SNQc00211H/groups/0SNQe0032JZ/remove
//     Content-Type: application/json
//
//     [ "0SNQe00311H", "0SNQg00511H" ]
//
// ### Example response
//     202 Accepted
//     Content-Type: application/json
//
//     { "at": [[1,113]] }
//
// # Errors
// 
// ## Returns `401 Unauthorized` 
// - ... if the provided token does allow acting as `{as}`.

TEST("Returns 401 when token is not valid.", function(Query) {
    var db = Query.mkdb();
    return Query.post(["db/",db,"/groups/admin/remove"],[],{id:"01234567890",token:"01234567890"})
	.assertStatus(401);
});

// ## Returns `403 Forbidden`
// - ... if `{as}` does not have at least **moderate** access to 
//   group `{id}`.

TEST("Returns 403 when no 'moderate' access.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db); 
    var id = Query.post(["db/",db,"/groups"],{"audience":{"list":"anyone"}},auth).id();
    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.post(["db/",db,"/groups/",id,"/remove"],[],peon)
	.assertStatus(403);
});

// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.post(["db/00000000000/groups/admin/remove"],[]).assertStatus(404);
});

// - ... if group `{id}` does not exist in database `{db}`

TEST("Returns 404 when group does not exist.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db); 
    return Query.post(["db/",db,"/groups/00000000000/remove"],[]).assertStatus(404);
});

// - ... if `{as}` does not have at least **view** access to group `{id}`,
//   to ensure [absence equivalence](/docs/#/concept/absence-equivalence.md).

TEST("Returns 404 when no 'view' access.", function(Query) {
    var db = Query.mkdb();
    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.post(["db/",db,"/groups/admin/remove"],[],peon).assertStatus(404);
});

// # Access restrictions
//
// An [access level](/docs/#/group/audience.js) of at least **moderate** is required
// to remove members from a group.
