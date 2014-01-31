// GET /db/{db}/contacts/{id}
// Contacts / Fetch basic information for contact {id}
//
// Alpha @ 0.1.21
//
// Contact information is represented as a [`<shortcontact>`](/docs/#/contact/short-contact.js).
//
// Expect a `200 OK` return code and an `application/json` content type. 

TEST("The response has valid return code and content type.", function(next) {
    next()
});

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

TEST("The example was properly returned", function(next) {
    next()
});

// 
// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function(next) {
    Test.query("GET","/db/00000000001/contacts/00000000002/").error(404).then(next);
});

// - ... if contact `{id}` does not exist in database `{db}`

TEST("Returns 404 when contact does not exist in database.", function(next) {
    var db = Query.mkdb(),
        token = Query.auth(db);

    Test.query("GET",["db/",db,"/contacts/00000000002/"],{},token).error(404).then(next);
});

// 
// ## Returns `401 Unauthorized` 
// - ... if the provided token does not provide access to the contact,
//   or no token was provided

TEST("Returns 401 when token is not valid.", function(next) {
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
