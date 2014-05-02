// PUT /db/{db}/forms/{id}
// Forms / Update a form
//
// Beta @ 0.9.0
//
// `202 Accepted`, [Delayed](/docs/#/concept/delayed.md), [Idempotent](/docs/#/concept/idempotent.md).
//
// Person [`{as}`](/docs/#/concept/as.md) updates the properties of a form. Note 
// that once a form has been filled (even if only
// once), the list of fields may not be updated (though other properties can). 
// 
// ### Request format
//     { "label" : <label> | null,
//       "custom": <json>,
//       "owner": "person",
//       "fields": [ <field>, ... ],
//       "audience": <audience> }
// - `label` is an optional [human-readable name](/docs/#/types/label.js).
// - `custom` is an arbitrary block of JSON that will be stored as-is by 
//   RunOrg and returned as such by the API.
// - `owner` is the nature of the owners associated with each filled instance
//   of the form. In the current version of the API, this is always `"person"`
//   (each instance is owned by a person). 
// - `fields` is an ordered list of [fields](/docs/#/form/field.js) to be 
//   filled.
// - `audience` is the [audience](/docs/#/form/audience.js) of the form.
// 
// The API will behave differently when a value is `null` and when it is missing. 
// For instance, `{"label":null}` will set the label to `null` and update nothing
// else, while `{}` will not update the label at all. 
//
// ### Response format
//     { "at" : <clock> }

var Example = { 
    "owner": "person",
    "audience": {},
    "fields": []
};

TEST("The response has valid return code and content type.", function(Query) {

    var db = Query.mkdb();
    var token = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Example,token).id();
    
    return Query.put(["db/",db,"/forms/",id],Example,token)
	.assertStatus(202).assertIsJson();

});


// ### Example request
//     PUT /db/0SNQc00211H/forms/0SNQe0032JZ
//     Content-Type: application/json
// 
//     { "label" : "Personal information", 
//       "audience" : {
//         "admin": {},
//         "fill": { groups: [ "0SNQe0032JZ" ] } } }
//
// ### Example response
//     202 Accepted
//     Content-Type: application/json
// 
//     { "at" : [[2,219]] }
//  
// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(Query) {

    return Query.put(["db/00000000000/forms/00000000001"],Example)
	.assertStatus(404);
        
});

// - ... if form `{id}` does not exist in database `{db}` 

TEST("Returns 404 when form does not exist.", function(Query) {

    var db = Query.mkdb();

    return Query.put(["db/",db,"/forms/00000000001"],Example)
	.assertStatus(404);
        
});

// - ... if person `{as}` cannot view form `{id}`, to ensure [absence 
//   equivalence](/docs/#/concept/absence-equivalence.md). 

TEST("Returns 404 when form cannot be viewed.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Example,auth).id();

    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.put(["db/",db,"/forms/",id],Example,peon)
	.assertStatus(404);

});

// ## Returns `409 Conflict`
// - ... if the form has already been filled, and the request attempts
//   to update the form fields.

TODO("Returns 409 when filled.");

// ## Returns `403 Forbidden` 
// - ... if person `{as}` does not have the **admin** access required to 
//   update the form.

TEST("Returns 403 if no admin access.", function(Query) {

    var example = $.extend({}, Example, { "audience": { "fill": "anyone" } });

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],example,auth).id();

    var peon = Query.auth(db,false,"peon@runorg.com");
    return Query.put(["db/",db,"/forms/",id],example,peon)
	.assertStatus(403);

});

// ## Returns `401 Unauthorized` 
// - ... if the provided token does not match person `{as}`,
//   or no token was provided

TEST("Returns 401 when token is not valid.", function(Query) {

    var db = Query.mkdb();
    var auth = Query.auth(db);
    var id = Query.post(["db/",db,"/forms"],Example,auth).id();

    return Query.put(["db/",db,"/forms/",id],Example,{tok:"0123456789a",id:"0123456789a"})
	.assertStatus(401);

});

// # Access restrictions
//
// Subject to the form's `admin` [audience](/docs/#/concept/audience.md).
