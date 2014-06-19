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
  { "id": <id>,
    "label": <label>,
    "gender": "F" | "M" | null,
    "pic": <url> }
</example>
<list tags="methods:person subclasses:person" />