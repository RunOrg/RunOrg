// GET /db/{db}/contacts/{id}
// Contacts / Fetch basic information for contact {id}
//
// Contact information is represented as a **ShortContact**:
//
// ### `ShortContact` JSON format
//     { id : <id>, 
//       name : <label>, 
//       gender : "F" | "M" | null,
//       pic : <url> }
// 
// - `id` is the unique 11-character identifier for this contact

TEST("The contact's identifier is returned.", function() {
    Assert.fail();
});

// - `name` is a human-readable name. This is the contact's 
//   `fullname` (if specified), otherwise RunOrg will do its best
//   to create a recognizable name in an unspecified fashion.
TEST("The contact's fullname is returned if available.", function() {
    Assert.fail();
});

TEST("The contact's firstname + lastname is returned if available.", function() {
    Assert.fail();
});

TEST("The contacts's email is returned if available.", function() {
    Assert.fail();
});

// - `gender` can be `"F"` for female, `"M"` for male, or left 
//   undefined.

TEST("The contact's gender is returned.", function() {
    Assert.fail();
});

// - `pic` is the URL of an avatar picture. Uses the contact's 
//   `pic` if specified, otherwise RunOrg will do its best to 
//   generate a reasonable avatar picture in an unspecified fashion. 

TEST("The contact's picture is returned if available.", function() {
    Assert.fail();
});

TEST("A gravatar is generated if no picture is available.", function() {
    Assert.fail();
});

// 
// # Errors
// 
// ## Returns `404 Not Found`
// - if database `{db}` does not exist

TEST("Returns 404 when database does not exist.", function() {
    Assert.fail();
});

// - if contact `{id}` does not exist in database `{db}`

TEST("Returns 404 when contact does not exist in database.", function() {
    Assert.fail();
});

// 
// ## Returns `401 Unauthorized` 
// - if the provided token does not provide access to the contact,
//   or no token was provided

TEST("Returns 401 when token is not valid.", function() {
});
