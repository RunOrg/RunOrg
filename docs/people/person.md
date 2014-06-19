<page title="Short information about a person"
      api="type <person>" 
      js="class RunOrg.Person"
      tags="types classes class:person"
      parent="people.md" />
<doc>
  This object contains basic information about a person, just enough 
  to be able to display their identity : 
</doc>
<fields>
  | id     | <id>           | The identifier of the person in the database.
  | label  | <label>        | A human-readable label. RunOrg will use the person's 
                              full name if available, and try to construct a label 
			      through another (undocumented) method otherwise.
  | gender | "F", "M", null | The gender of the person.
  | pic    | <url>          | A 80px &times; 80px picture representing the person. 
</fields>
<example type="json">
  { "id": "1c39461xbF3",
    "label": "Victor Nicollet",
    "gender": "F",
    "pic": "https://www.gravatar.com/avatar/5a31b00f649489a9a24d3dc3e8b28060?d=identicon" }
</example>
<list tags="methods:person subclasses:person" />
<doc>
  For privacy purposes, the short information will never include contact information,
  such as a _full_ e-mail address or phone number. To ensure that this is the case, 
  make sure you correctly classify any contact information as such. 
</doc>
