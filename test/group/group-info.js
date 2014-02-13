// JSON <groupinfo>
// Groups / A short representation of a group's information
// 
// Returned by most API methods that involve contacts. It is intended to 
// provide data relevant for displaying the contact: its name, picture 
// and gender. 
// 
// Typical examples: [listing public groups](/docs/#/group/public.js) or 
// [groups participating in a chat](/docs/#/chat/get.js). 
//
// ### `ShortContact` JSON format
//     { id : <id>, 
//       label : <label> | null, 
//       count : <int> }
// 
// - `id` is the [unique 11-character identifier](/docs/#/types/id.js) for this 
//   contact

TEST("The groups's identifier is returned.", function() {
    Assert.fail();
});

// - `label` is a [human-readable name](/docs/#/types/label.js). Not all groups
//   have one, because it is not a mandatory property when creating a group.
TEST("The groups's label is returned if available.", function() {
    Assert.fail();
});

// - `count` is the number of group members (contacts currently in the group).

TEST("The group's member count is returned.", function() {
    Assert.fail();
});

// ### Example value
//     { "id" : "0Et9j0026rO",
//       "label" : "Team members",
//       "count": 16 }
//
// If you end up with a group's id but not its basic information, this usually
// means the group has gone missing from the database. You can still
// [try to get its data directly](/docs/#/group/info.js), but it is not likely
// to work.
