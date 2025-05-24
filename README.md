# What is Multirun ?
> Multirun is a dotnet plugin that supports running, building, and stopping multiple dotnet projects at the same time

## How does it differ than easy dotnet?
> Multirun only aims at running the dotnet run or dotnet build commands on multiple projects (or single projects) simaltanously. If other dotnet commands are needed then use easy dotnet too

## Getting Started
> Run the DotnetStartPicker command (or keymap) to launch the picker
 - The first picker will be the command to run
  - build
    - builds the selected projects
  - run
    - will build and run the selected projects and dependencies
    - equalivent to running dotent run commands
    - use this when the projects are in separate solutions (no shared code)
  - build and run
    - will run a single build command separatly then execute the run command for each project
    - run command is equalivent to dotnet run --no-build
    - use this when the projects to run are apart of the same solution

 - The second picker will be the projects to run
  - utilizes telescopes multiselection feature by pressing Tab to select multiple files
  - when pressing enter, the commands will be executed

> To Stop the running commands execute DotnetStopRunningProjects or the keymap
> To rerun the previous command on the previously selected projects run DotnetRunPrevious or keymap (this skips the picker)
> To Close the project window execute DotnetCloseProjectWindow or keymap

> Setup
 - one configuration for enabling auto cleanup of the project tab when a new command is executed or projects are stopped.

 With lazy
 ```nvim
 ```
