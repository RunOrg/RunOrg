// GET /db/{db}/forms/{id}/filled
// Forms / List all filled instances of a form.
// 
// Alpha @ 0.1.44
//
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md),
// [Paginated](/docs/#/concept/paginated.md).
//
// Returns all the filled instances of form `{id}`.
// Supports `limit` and `offset` pagination. 
//
// ### Response format
//     { "list": [ { 
//          "owner": <id>,
//          "data": { <key> : <value> }
//        }, ... ],
//       "count": <int> }
// - `list` is a list of form instances on the requested page.
// - `list[].owner` is the identifier of the entity that owns the filled
//   form instance, such as a contact.
// - `list[].data` is the data used to [fill the form](/docs/#/form/fill.js),
//   returned as-is.
// - `count` is the number of form instances available. 

var Form = { 
    "owner": "contact",
    "audience": {},
    "fields": [ { 
	"id": "color",
	"kind": "text",
	"label": "Favourite color"
    } ]
};


TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Form,auth).id();

    return Query.get(["db/",db,"/forms/",id,"/filled"],auth)
	.assertStatus(200).assertIsJson();

});

// # Examples
// 
// ### Example request
//     GET /db/0SNQc00211H/forms/0SNQc00711H/filled?as=0Sd7003511H&limit=3&offset=213
// 
// ### Example response
//     200 OK
//     Content-Type: application/json 
//     
//     { "list" : [ { 
//         "owner" : "0SNQe00311H",
//         "data": { "color" : "Orange", "birth" : "1985-04-19" } 
//       }, { 
//         "owner" :  "0SNQe00311H",
//         "data": { "birth" : "2013-10-08" }
//       } ],
//       "count": 215 }

TEST("Returns correct items and count.", function(Query) {

    var form = {
	"owner": "contact",	
	"audience": { "fill": "anyone" },
	"label": "Join form",
	"fields": [ {
	    "id": "1",
	    "label": "Why did you join our group ?",
	    "kind": "text",
	    "required": true
	} ]
    };

    var data1 = {"data":{"1":"Networking"}};
    var data2 = {"data":{"1":"Recommendation"}};

    var db = Query.mkdb();
    var auth = Query.auth(db);

    return Query.post(["db/",db,"/forms"],form,auth).id().then(function(id) {
	
	var peon = Query.auth(db,false,"peon@runorg.com");

	return Query.put(["db/",db,"/forms/",id,"/filled/",auth.id],data1,auth).then(function() {
	    return Query.put(["db/",db,"/forms/",id,"/filled/",peon.id],data2,auth).then(function() {

		var item1 = { "owner" : auth.id, "data" : data1.data };
		var item2 = { "owner" : peon.id, "data" : data2.data };
		
		var expected1 = { "list" : [ item1, item2 ], "count" : 2 };
		var expected2 = { "list" : [ item2 ], "count" : 2 };
		var expected3 = { "list" : [ item1 ], "count" : 2 };
		
		var list1 = Query.get(["db/",db,"/forms/",id,"/filled"],auth)
		    .then(function(d) { return d; });
		
		var list2 = Query.get(["db/",db,"/forms/",id,"/filled?offset=1"],auth)
		    .then(function(d) { return d; });
		
		var list3 = Query.get(["db/",db,"/forms/",id,"/filled?limit=1"],auth)
		    .then(function(d) { return d; });
		
		return $.when(
		    Assert.areEqual(expected1, list1),
		    Assert.areEqual(expected2, list2),
		    Assert.areEqual(expected3, list3)
		);
	    });
	});
    });

});

// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(Query) {
    return Query.get(["db/00000000000/forms/00000000001/filled"]).assertStatus(404);
});

// - ... if form `{id}` does not exist in database `{db}` 

TEST("Returns 404 when form does not exist.", function(Query) {
    var db = Query.mkdb();
    return Query.get(["db/",db,"/forms/00000000001/filled"]).assertStatus(404);
});

// - ... if contact `{as}` cannot view form `{id}`

TEST("Returns 404 when form cannot be viewed.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Form,auth).id();
    
    return Query.get(["db/",db,"/forms/",id,"/filled"]).assertStatus(404);

});

// ## Returns `403 Forbidden`
// - ... if contact `as` does not have **admin** access to the form.

TEST("Returns 403 when form cannot be viewed.", function(Query) {

    var form = $.extend({},Form,{"audience":{"fill":"anyone"}});

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],form,auth).id();
    var peon = Query.auth(db,false,"peon@runorg.com");

    return Query.get(["db/",db,"/forms/",id,"/filled"],peon).assertStatus(403);

});

// ## Returns `401 Unauthorized` 
// - ... if the provided token does not grant mathch contact `{as}`.

TEST("Returns 401 when token is not valid.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Form,auth).id();
 
    return Query.get(["db/",db,"/forms/",id,"/filled"],{token:"012345789a",id:"0123456789a"})
	.assertStatus(401);
});
 
// # Access restrictions
//
// [**Admin** access](/docs/#/form/audience.js) is required to view all filled form instances. 
