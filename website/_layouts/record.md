---
layout: default
---

<h1>{{ page.record.id | upcase }} Record</h1>

<p>
{{ page.record.description }}
</p>

<table>
<thead>
  <tr>
    <th>ID</th>
    <th>Name</th>
    <th>Type</th>
  <tr>
</thead>
<tbody>
{% for field in page.record.fields %}
  <tr>
    <td><a href="#{{ field.id }}">{{ field.id }} {% if field.primary_key %} <b>[PK]</b>{% endif %}</a></td>
    <td>{{ field.name }}</td>
    <td>{{ field.type }}</td>
  </tr>
{% endfor %}
</tbody>
</table>

{% for field in page.record.fields %}
<section id="{{field.id}}">
<h2 >{{field.id}}: {{field.name}}</h2>
<p>{{ field.description }}</p>

<table>
  <tr><th>Type</th><td>{{ field.type }}</td></tr>
{% if field.primary_key %}
  <tr><th>Primary Key</th><td>True</td></tr>
{% endif %}
{% if field.validation.required %}
  <tr><th>Required</th><td>True</td></tr>
{% endif %}
<tr><th>Validators</th><td>{% for v in field.validation %} {{v[0]}} {% endfor %}</td></tr>

</table>

</section>
{% endfor %}
