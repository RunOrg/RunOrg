// POST /db/{db}/groups/{id}/add
// Groups / Add members to a group
// 
// Beta @ 0.9.0
//
// `202 Accepted`,
// [Delayed](/docs/#/concept/delayed.md),
// [Idempotent](/docs/#/concept/idempotent.md).
//
// Adds the provided people to the specified group. People already
// in the group are silently ignored. 
// 
// ### Request format
//     [ <id>, ... ]
//
// The people are passed as an array of identifiers. 

TEST("The response has valid return code and content type.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.post(["db/",db,"/groups/admin/add"],[peon.id],auth)
	.assertStatus(202).assertIsJson();    
});

TEST("An empty list is acceptable.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.post(["db/",db,"/groups/admin/add"],[],auth)
	.assertStatus(202);    
});

TEST("Duplicate contacts in list are acceptable.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.post(["db/",db,"/groups/admin/add"],[peon.id,peon.id],auth)
	.assertStatus(202);    
});

TEST("Contacts already in group are ignored.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.post(["db/",db,"/groups/admin/add"],[auth.id],auth)
	.assertStatus(202);    
});

TEST("Added contacts can be found in the group.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var peon = Query.auth(db,false,"test+2@runorg.com");
    return Query.post(["db/",db,"/groups/admin/add"],[peon.id,peon.id],auth).then(function() {

	var list = Query.get(["db/",db,"/groups/admin"],auth).then(function(d) { return d.list; });
	var expected = [{
	    "id" : auth.id,
	    "label" : "test@…",
	    "gender" : null,
	    "pic" : "https://www.gravatar.com/avatar/1ed54d253636f5b33eff32c2d5573f70?d=identicon"
	}, {
	    "id" : peon.id,
	    "label" : "test+2@…",
	    "gender" : null,
	    "pic" : "https://www.gravatar.com/avatar/fcf1ec969e2da183f88f5a6dca0c1d65?d=identicon"
	}];
	
	return Assert.areEqual(expected,list);
    });
});

// # Examples
// 
// ### Example request
//     POST /db/0SNQc00211H/groups/0SNQe0032JZ/add
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
// - ... if the provided token does not allow acting as `{as}`

TEST("Returns 401 when token is not valid.", function(Query) {
    var db = Query.mkdb();
    return Query.post(["db/",db,"/groups/admin/add"],[],{id:"01234567890",token:"01234567890"})
	.assertStatus(401);
});

// ## Returns `403 Forbidden`
// - ... if person `{as}` does not have at least **moderate** access to 
//   group `{id}`

TEST("Returns 403 when no 'moderate' access.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db); 
    var id = Query.post(["db/",db,"/groups"],{"audience":{"list":"anyone"}},auth).id();
    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.post(["db/",db,"/groups/",id,"/add"],[],peon)
	.assertStatus(403);
});

// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.post(["db/00000000000/groups/admin/add"],[]).assertStatus(404);
});

// - ... if group `{id}` does not exist in database `{db}`

TEST("Returns 404 when group does not exist.", function(Query) {
    var db = Query.mkdb();
    return Query.post(["db/",db,"/groups/00000000000/add"],[]).assertStatus(404);
});

// - ... if person `{as}` does not have at least **view** access to 
//   group `{id}`, to ensure [absence equivalence](/docs/#/concept/absence-equivalence.md)

TEST("Returns 404 when no 'view' access.", function(Query) {
    var db = Query.mkdb();
    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.post(["db/",db,"/groups/admin/add"],[],peon).assertStatus(404);
});

// - ... if one of the added people does not exist in database `{db}`

TEST("Returns 404 when person does not exist.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.post(["db/",db,"/groups/admin/add"],["00000000000"],auth).assertStatus(404);
});
 
// # Access restrictions
//
// The **moderate** [access level](/docs/#/group/audience.js) is required
// to add members to a group.
