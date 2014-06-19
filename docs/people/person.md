<page title="Short information about a person"
      api="type <person>" 
      js="class RunOrg.Person"
      tags="types classes class:person"
      parent="people.md" />
<doc>
  This object contains basic information about a person, just enough 
  to be able to display their identity : 
</doc>
<example type="json">
  { "id": <id>,
    "label": <label>,
    "gender": "F" | "M" | null,
    "pic": <url> }
</example>
<list tags="methods:person subclasses:person" />