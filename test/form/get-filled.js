// GET /db/{db}/forms/{id}/filled/{owner}
// Forms / Get the data from a filled form.
// 
// Alpha @ 0.1.43
//
// `200 OK`, 
// [Read-only](/docs/#/concept/read-only.md).
//
// Contact [`{as}`](/docs/#/concept/as.md) retrieves returns the data entered into
// an instance of form `{id}` bound to entity `{owner}`. 
//
// ### Response format
//     { "data": { <key> : <value> },
//       "owner": <id> }
//
// - `data` contains a dictionary mapping field names to arbitrary JSON values, 
//   as they were provided when [filling the form](/docs/#/form/fill.js). 
// - `owner` contains the owner identifier provied in the URL: it identifies the
//   entity to which the filled form instance is bound.  
//

var Form = { 
    "owner": "contact",
    "audience": {},
    "fields": [ { 
	"id": "color",
	"kind": "text",
	"label": "Favourite color"
    } ]
};

var Data = { "data": { "color" : "Red" } };

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Form,auth).id();

    return Query.put(["db/",db,"/forms/",id,"/filled/",auth.id],Data,auth).then(function() {
	return Query.get(["db/",db,"/forms/",id,"/filled/",auth.id],auth)
	    .assertStatus(200).assertIsJson();
    });
});

// # Examples
// 
// ### Example request
//     GET /db/0SNQc00211H/forms/0SNQe0032JZ/filled/0SNxd0002JZ?as=0SNxd0002JZ
// 
// ### Example response
//     200 OK
//     Content-Type: application/json 
//     { "data" : {
//         "color" : "orange",
//         "born"  : "1985-04-18" },
//       "owner" : "0SNxd0002JZ" }

TEST("Returns correct data.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Form,auth).id();

    return Query.put(["db/",db,"/forms/",id,"/filled/",auth.id],Data,auth).then(function() {
	return Query.get(["db/",db,"/forms/",id,"/filled/",auth.id],auth).then(function(d,s,r) {

	    var expected = {
		"owner" : auth.id,
		"data" : Data.data
	    };

	    return Assert.areEqual(expected, d);

	});
    });

});


// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(Query) {

    return Query.get(["db/00000000000/forms/00000000001/filled/00000000002"])
	.assertStatus(404);

});

// - ... if form `{id}` does not exist in database `{db}`

TEST("Returns 404 when form does not exist.", function(Query) {

    var db = Query.mkdb();

    return Query.get(["db/",db,"/forms/00000000001/filled/00000000002"])
	.assertStatus(404);

});

// - ... if form `{id}` has not been filled for entity `{owner}`.

TEST("Returns 404 when form is not filled.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Form,auth).id();

    return Query.get(["db/",db,"/forms/",id,"/filled/",auth.id],auth)
	.assertStatus(404);

});


// - ... if contact `{as}` is not allowed to view form `{id}, to ensure 
// [absence equivalence](/docs/#/concept/absence-equivalence.md). 

TEST("Returns 404 when form not viewable.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Form,auth).id();

    return Query.put(["db/",db,"/forms/",id,"/filled/",auth.id],Data,auth).then(function() {
    
	var peon = Query.auth(db,false,"peon@runorg.com");
	return Query.get(["db/",db,"/forms/",id,"/filled/",auth.id],peon)
	    .assertStatus(404);

    });
});


// ## Returns `401 Unauthorized` 
// - ... if the provided auth does not grant access as the named 
//   contact, or no auth was provided

TEST("Returns 401 when auth is not valid.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Form,auth).id();

    return Query.get(["db/",db,"/forms/",id,"/filled/",auth.id],{tok:"0123456789a",id:"0123456789a"})
	.assertStatus(401);    

});


// ## Returns `403 Forbidden`
// - ... if contact `{as}` is can view the form, but not the requested 
//   instance. For instance, without **admin** access, a contact may only
//   view the instance bound to himself (`{owner} == {as}`), and not to 
//   other contacts. Access restrictions are defined for each type of 
//   owner.

TEST("Returns 403 when form instance not viewable.", function(Query) {

    var form = $.extend({},Form,{"audience":{"fill":"anyone"}})

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],form,auth).id();

    return Query.put(["db/",db,"/forms/",id,"/filled/",auth.id],Data,auth).then(function(){
    
	var peon = Query.auth(db,false,"peon@runorg.com");
	return Query.get(["db/",db,"/forms/",id,"/filled/",auth.id],peon)
	    .assertStatus(403);

    });
});


// # Access restrictions
//
// Contact must have `fill` [audience](/docs/#/form/audience.md) access to 
// the form, and be able to view the instance.
