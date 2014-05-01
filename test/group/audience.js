// JSON <group-audience>
// Groups / Group audience and access levels
//
// ### Example audience
//     "audience" : {
//       "admin": {},
//       "moderate": {},
//       "list": "anyone",
//       "view": {}
//     }
//
// Groups support the following [access levels](/docs/#/concept/audience.md): 
//
// # Administrating the group
//
// The **admin** access allows any operations that can be performed on 
// the group, including changing its name, meta-data or access levels. 
//
// It includes the **moderate**, **list** and **view** access levels. 
//
// # Moderating the group
//
// The **moderate** access allows:
//
// - Adding people to the group
// - Removing people from the group
// 
// It includes **list** and **view** access levels.
//
// # Listing the group members
// 
// The **list** access allows viewing the full list of group members, 
// and any information related to their membership (such as when they
// became members and how).
// 
// Most operations that involve interacting with group members (such 
// as sending an e-mail or inviting to a chat room) will require this 
// access level.
//
// It includes **view** access.
// 
// # Viewing the group
// 
// The **view** access allows viewing the group's label, and whether
// the contact is a member of that group. No other information is
// available.
 