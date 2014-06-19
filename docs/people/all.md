<page title="List all people in the database"
      api="GET /db/{db}/people"
      js="static RunOrg.Person.List" 
      tags="methods:person" />

<doc for="js">
  `RunOrg.Person.List(limit, offset)` reads `limit` people from the 
  database, starting at `offset`. The order is unspecified but 
  consistent. 

  Returns a [promise](/concepts/promise.md) that will resolve to a 
  list of filled `RunOrg.Person` instances. 
</doc>
<example type="js" caption="Example usage">
  RunOrg.Person.List(10, 0).then(function(list) {
    for (var i = 0; i < list.length; ++i) 
      console.log("Person %s is %s", list[i].id, list[i].label)    
  })			 
</example>

<todo> Explain how to handle errors. </todo>
<todo> Implement and document extracting "count" from the API in JS </todo>

<doc for="api">
  Returns all the people in the database, in an unspecified but consistent
  order, with [pagination](/concepts/pagination.md). 
</doc>

<fields caption="Response fields" for="api">
  | list  | <person> array | A list of people on the requested page.
  | count | integer        | The total number of people in the database.                          
</fields>

<example type="api" caption="Example request">
  GET /db/0SNQc00211H/people?limit=3&offset=213
</example>
<example type="api" caption="Example response">
  200 OK
  Content-Type: application/json 
    
  { "list" : [ 
    { "id" : "0SNQe00311H",
      "name" : "test@runorg.com",
      "gender" : null,
      "pic" : "https://www.gravatar.com/avatar/1ed54d253636f5b33eff32c2d5573f70" },
    { "id" : "0SNQg00511H",
      "name" : "vnicollet@runorg.com",
      "gender" : null,
      "pic" : "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060"} ],
    "count" : 215 }
</example>

<doc>

# Errors

## Returns `401 Unauthorized` 
- if the provided token and requester do not match. 

## Returns `403 Forbidden` 
- if the requester is not a database administrator

## Returns `404 Not Found`
- if the database does not exist

# Access restrictions

Only [database administrators](/groups/admin.md) may list all people
in the database. 

Note that [viewing individuals](/people/get.js) is open to anyone.

</doc>