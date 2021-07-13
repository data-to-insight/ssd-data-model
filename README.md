# Data model for the Refugee Transitions Outcomes Fund (RTOF)

This is the source repository for the RTOF data model and includes tools for generating different outputs from the core
specification. 

## Generate outputs

The documentation generator uses [Poetry][poetry] for dependency management. Make sure you have poetry installed, then install
the project dependencies:

```
poetry install
```

Once installed, you can either run the generator from the command line by typing:

```
poetry run python main.py <full-filename-to-datamodel-excel>
```

or you can launch VS Code with:

```
poetry shell
code .
```