// GET /db/{db}/contacts/{id}
// Contacts / Fetch basic information for contact {id}
//
// Alpha @ 0.1.21
//
// Contact information is represented as a [`<shortcontact>`](/docs/#/contact/short-contact.js).
//
// Expect a `200 OK` return code and an `application/json` content type. 

TEST("The response has valid return code and content type.", function() {
    Assert.fail();
});

// 
// # Errors
// 
// ## Returns `404 Not Found`
// - ... if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function() {
    Assert.fail();
});

// - ... if contact `{id}` does not exist in database `{db}`

TEST("Returns 404 when contact does not exist in database.", function() {
    Assert.fail();
});

// 
// ## Returns `401 Unauthorized` 
// - ... if the provided token does not provide access to the contact,
//   or no token was provided

TEST("Returns 401 when token is not valid.", function() {
});

// 
// # Access restrictions
//
// Currently, anyone can view any contact's basic information with a token for the 
// corresponding database. This is subject to change in future versions.
