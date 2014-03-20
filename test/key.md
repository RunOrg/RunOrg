Keys

A **key** means a cryptographic key, used for HMAC-based
authentication of certain requests. Keys are used to allow third party
software to communicate with the RunOrg API through an insecure
channel, such as through tokens handled in the client browser.

For instance, you can use keys to [securely authenticate](/docs/#/contact/hmac.js) 
an user that is already logged into another service you control:

1. Dave, the _developer_, generates a new **key** (a random sequence
   of bytes) and registers it with API using the [create
   key](/docs/#/key/create.js) endpoint. This yields a **key-id**.
2. Dave then stores both the key and the key-id in MyTestApp (his own
   application).
3. Alice, the _user_, connects to MyTestApp.  
4. MyTestApp creates an **assertion** that says "Until date X, assume
   the holder of this assertion to be Alice", and computes a
   cryptographic **proof** by applying `HMAC-SHA1(key,assertion)`.
5. Alice receives the assertion, the proof and the key-id from
   MyTestApp, and sends it to RunOrg.
6. RunOrg uses the key-id to retrieve the key from its internal database,	
   computes `HMAC-SHA1(key,assertion)` and compares it with the provided
   proof. If they match, then it is certain that the assertion was 
   generated by MyTestApp, and so RunOrg authenticates Alice. 	    
7. Alice receives a RunOrg token and can start using the API.

It is recommended to keep one API key for each third party
application, and to disable individual keys if they are leaked or
become too old.