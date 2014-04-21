// GET /db/{db}/contacts/{id}
// Contacts / Fetch basic information for contact {id}
//
// Alpha @ 0.1.21
//
// `200 OK`, [Read-only](/docs/#/concept/read-only.md).
//

TODO("The response has valid return code and content type.", function(next) {

    var example = { "email" : "vnicollet@runorg.com" };

    var db = Query.mkdb(),
        token = Query.auth(db),
        id = Test.query("POST",["db/",db,"/contacts/import"],[example],token).result('created',0),
        response = Test.query("GET",["db/",db,"/contacts/",id],{},token).response();

    response.map(function(r) {
	Assert.areEqual(200, r.status).then();
	Assert.isTrue(r.responseJSON, "Response type is JSON").then();
    }).then(next);

});

// Returns a short representation of the specified contact, as a 
// [`<shortcontact>`](/docs/#/contact/short-contact.js).
//
// ### Example request
//     GET /db/0Et4X0016om/contacts/0Et9j0026rO
//     
// ### Example response
//     200 OK 
//     Content-Type: application/json
//
//     { "id" : "0Et9j0026rO",
//       "name" : "Victor Nicollet",
//       "gender" : "M", 
//       "pic" : "https://www.gravatar.com/avatar/648e25e4372728b2d3e0c0b2b6e26f4e" }

TODO("The example was properly returned.", function(next) {

    var example = { "email" : "vnicollet@runorg.com",
		    "fullname" : "Victor Nicollet",
		    "gender" : "M" };

    var db = Query.mkdb(),
        token = Query.auth(db),
        id = Test.query("POST",["db/",db,"/contacts/import"],[example],token).result('created',0),
        created = Test.query("GET",["db/",db,"/contacts/",id],{},token).result();

    var expected = { "id": id, 
		     "name": "Victor Nicollet",
		     "gender": "M", 
		     "pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060" };

    Assert.areEqual(expected, created).then(next);

});

// 
// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TODO("Returns 404 when database does not exist.", function(next) {
    Test.query("GET","/db/00000000001/contacts/00000000002/").error(404).then(next);
});

// - ... if contact `{id}` does not exist in database `{db}`

TODO("Returns 404 when contact does not exist in database.", function(next) {
    var db = Query.mkdb(),
        token = Query.auth(db);

    Test.query("GET",["db/",db,"/contacts/00000000002/"],{},token).error(404).then(next);
});

// 
// ## Returns `401 Unauthorized` 
// - ... if the provided token does not provide access to the contact,
//   or no token was provided

TODO("Returns 401 when token is not valid.", function(next) {
    var db = Query.mkdb();
    Test.query("GET",["db/",db,"/contacts/00000000002/"]).error(401).then(function() {
	Test.query("GET",["db/",db,"/contacts/00000000002/"],{},"0123456789a").error(401).then(next);
    });
});

// 
// # Access restrictions
//
// Currently, anyone can view any contact's basic information with a token for the 
// corresponding database. This is subject to change in future versions.
