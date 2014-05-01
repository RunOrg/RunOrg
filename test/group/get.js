// GET /db/{db}/groups/{id}
// Groups / List all group members
// 
// Alpha @ 0.1.23
//
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md),
// [Paginated](/docs/#/concept/paginated.md).
//
// Returns all the [people](/docs/#/person.md) in the specified group, in 
// arbitrary order. Supports `limit` and `offset` pagination. 
//
// ### Response format
//     { "list": [ <person>, ... ],
//       "count": <int> }
// - `list` is a list of contacts on the requested page, in 
//   [short format](/docs/#/person/short.js)
// - `count` is the total number of members in the group.

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/groups"],{},auth).id();
    return Query.get(["db/",db,"/groups/",id],auth)
	.assertStatus(200).assertIsJson();

});

// # Examples
// 
// ### Example request
//     GET /db/0SNQc00211H/groups/0SNQe0032JZ?limit=3&offset=213
// 
// ### Example response
//     200 OK
//     Content-Type: application/json 
//     
//     { "list" : [ 
//       { "id" : "0SNQe00311H",
//         "label" : "George Sand",
//         "gender" : "f",
//         "pic" : "https://www.gravatar.com/avatar/1ed54d253636f5b33eff32c2d5573f70" },
//       { "id" : "0SNQg00511H",
//         "label" : "Victor Hugo",
//         "gender" : "m",
//         "pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28061"} ],
//       "count" : 215 }

TEST("Returns correct number of contacts in count.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var other = Query.auth(db,true,"test+2@runorg.com");
    
    return $.when(auth,other).then(function() {
	var count = Query.get(["db/",db,"/groups/admin?limit=1"],auth).then(function(d) { return d.count; });
	return Assert.areEqual(2,count);
    });
    
});

TEST("Returns data for all contacts.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);

    return auth.id.then(function() {

	var other = Query.auth(db,true,"test+2@runorg.com");
    
	return other.id.then(function() {

	    var list = Query.get(["db/",db,"/groups/admin"],auth).then(function(d) { return d.list; });
	    var expected = [{
		"id" : auth.id,
		"label" : "test@runorg.com",
		"gender" : null,
		"pic" : "https://www.gravatar.com/avatar/1ed54d253636f5b33eff32c2d5573f70?d=identicon"
	    }, {
		"id" : other.id,
		"label" : "test+2@runorg.com",
		"gender" : null,
		"pic" : "https://www.gravatar.com/avatar/fcf1ec969e2da183f88f5a6dca0c1d65?d=identicon"
	    }];
	    
	    return Assert.areEqual(expected,list);

	});
    });

});

// # Errors
//
// ## Returns `401 Unauthorized` 
// - ... if the provided token does not allow acting as `{as}`.

TEST("Returns 401 when token is not valid.", function(Query) {
    var db = Query.mkdb();
    return Query.get(["db/",db,"/groups/admin"],{id:"01234567890",token:"01234567890"})
	.assertStatus(401);
});

// 
// ## Returns `403 Forbidden`
// - ... if `{as}` does not have **list** access to the group.

TEST("Returns 403 when no 'list' access.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/groups"],{"audience":{"view":"anyone"}},auth).id();	
    var peon = Query.auth(db, false, "peon@runorg.com");
    return Query.get(["db/",db,"/groups/",id])
	.assertStatus(403);
});

// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.get(["db/00000000000/groups/admin"]).assertStatus(404);
});

// - ... if group `{id}` does not exist in database `{db}`
TEST("Returns 404 when group does not exist.", function(Query) {
    var db = Query.mkdb();
    var auth = Query.auth(db);
    return Query.get(["db/",db,"/groups/00000000000"],auth).assertStatus(404);
});

// - ... if `{as}` does not have at least **view** access to the 
//   group, to ensure [absence equivalence](/docs/#/concept/absence-equivalence.md)

TEST("Returns 404 when no 'view' access.", function(Query) {
    var db = Query.mkdb();
    // Create admin to auto-create admin group
    return Query.auth(db).id.then(function() {
	var peon = Query.auth(db,false,"peon@runorg.com");
	return Query.get(["db/",db,"/groups/admin"],peon).assertStatus(404);
    });
});

// # Access restrictions
//
// An [access level](/docs/#/group/audience.js) of **list** is 
// required to view the members of a group.