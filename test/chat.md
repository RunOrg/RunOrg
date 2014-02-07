Chatrooms

A **chatroom** is a list of participants and a list of items shared
between them.

The **participants** are listed as either [groups](/docs/#/group.md)
or individual [contacts](/docs/#/contact.md).

Chatroom messages are called **items**, and are not necessarily pieces
of text (arbitrary content is allowed, with the client being
responsible for rendering any custom formats).

Some chatrooms implement **private messaging** (abbreviated as `pm`): 
 - they have a fixed list of participants (two contacts);
 - they have no label or name;
 - they are only accessible to those participants (no reading or 
   writing by anyone else);
 - for any pair of contacts, there exists at most one `pm` chatrooms,
   which is _the_ private messaging history for those two contacts.

Non-`pm` chatrooms are free in terms of participants, read/write
access, and so on. 
