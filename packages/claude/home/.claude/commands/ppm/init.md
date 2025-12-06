
Each subdirectory of the current directory contains a separate stand-alone project

For the duration of our session together we will work on exactly one project

Each project follows a standardized set of top and second level directories

The project's top level directory 'source' may have one or more of the following subdirectories

- chats: ignore the contents of this directory
- drafts: ignore the contents of this directory
- plans: this contains the project requirements and implementation plans
- phases: this contains a file for each phase of the implementation
- reviews: this contains reviews of existing code
- pseudo: this contains pseudo code that represents what could be implemented

The project's other top level directory 'work' may have one or more of the following subdirectories:

- code: this directory will contain all of the output of your code generation
- docs: this directory will contain all of the output of your generated documentation of the code in markdown format


The first step of our session will be for you to prompt me for which project to activate. Please display a list of the available projects when doing so

To get started on the chosen project, look for a file named analysis.md in the source directory

If the file exists then read it and treat it as the context of this project

If the file does not exist then analyze the contents of the source/plans directory to get an overview of the project and write the analysis to analysis.md

In both cases:

- Do not analyze the contents of any of the other directories
- Do not generate anything now

I will let you know what the next step will be
