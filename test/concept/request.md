Concepts / API Requests

The RunOrg API is available over HTTPS. The client (a web browser, a
smartphone application or even another server) sends **requests** to
the API to extract or change the data stored by RunOrg.

# Endpoints

A request is processed by an **endpoint**, determined by the URL of
the request and the HTTP verb used. For example, a `GET` request on
`/db/0F23Zwt452/groups` would be processed by the endpoint that lists
all groups in a database. This endpoint is known as: 

    GET /db/{db}/groups

RunOrg uses standard HTTP conventions: 

 - `GET` requests retrieve data. 
 - `POST` requests are used to create things. 
 - `PUT` requests are used to change things.
 - `DELETE` requests are used to delete things. 

# Query string

The **query string** identifies the endpoint (along with the HTTP
verb) and provides additional **parameters**. 

### Query string example
    /db/0F23Zwt452/groups?as=0SNxd0002JZ&at=[[2,11369]]
    
 - `/db/{db}/groups` is the endpoint. 
 - `0F23Zwt452` (the second segment) is the identifier of the database 
   on which the request will execute.
 - `?as&at` are two parameters, with values of `0SNxd0002JZ` and 
   `[[2,11369]]` respectively.

Typical parameters include:

 - `as` is used to act as a specific individual (most of the time, 
   people can only act as themselves). See [Identity](/docs/#/concept/as.md).
 - `at` is used to wait for a previous operation to complete, such as
   waiting for a message to be created before displaying it. See
   [Synchronization](/docs/#/concept/synchronization.md).
 - `limit` and `offset` are used for some endpoints that return lists of
   things. See [Pagination](/docs/#/concept/paginated.md).

Specific endpoints may define other parameters, but this is quite rare.

# Authorization and tokens

For security reasons, RunOrg does not use cookies for authenticating
requests. Instead, authentication uses **tokens** passed through the 
`Authorization:` HTTP header.

For example, to use the token `9dF3M1wEma4`, the request headers should
contain: 

    Authorization: RUNORG token=9dF3M1wEma4 

Your HTTP client library provides a method for setting this header. 

### Example jQuery code

    $.ajax({

      type: 'GET',
      url: 'https://api.runorg.com/db/' + db + '/groups?as=' + id,

      dataType: 'json',
      success: onSuccess,

      beforeSend: function(xhr) { 
        xhr.setRequestHeader('Authorization','RUNORG token=' + token)
      }

    });

To obtain a token, you may use [Persona](/docs/#/contact/persona.js)
as a third party identity provider, or you may use your own using the
[HMAC-based protocol](/docs/#/contact/hmac.js).

# Request bodies

Unless otherwise noted, the body of a `POST` or `PUT` request must be
formatted as [proper ECMA-404 JSON](http://json.org/). Most languages
support JSON serialization, such as
[`JSON.stringify`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON/stringify)
in JavaScript or
[`json_encode`](http://php.net/manual/en/function.json-encode.php) in
PHP.

The request must include the HTTP header `Content-Type: application/json`. 

### Example jQuery code
    
    $.ajax({

      type: 'POST',
      url: 'https://api.runorg.com/db/' + db + '/contacts/auth/persona',
      contentType: 'application/json',
      data: JSON.stringify({ assertion: assertion }),

      dataType: 'json',    
      statusCode: { 202: onSuccess }

    });

# Responses

Unless otherwise noted, responses are formatted as
[JSON](http://json.org/) with a `Content-Type: application/json`
header. Each endpoint has its own specific format, documented on the
corresponding page, but there are several recurring patterns:

 - Requests for a single object return `200 OK` and contain the
   JSON representation of that object.
 - Requests for lists of objects return `200 OK` and contain the array
   of objects in a `list` fields. They sometimes provide a `count` 
   field with the total number of such objects in the database.
 - [Delayed](/docs/#/concept/delayed.md) requests have a `202
   Accepted` HTTP status code, and their body contains an `at` field
   documenting when the operation will be finished.
 - Requests involving missing objects have a `404 Not Found` status.
 - Requests that need additional permissions have a `403 Forbidden` 
   status. If the user is not logged in, this is a good time to ask.
 	  

