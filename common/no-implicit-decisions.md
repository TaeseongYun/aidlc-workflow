# No Implicit Decisions

The AI must not make the following decisions implicitly.

- Business policy choices
- Exception handling policy choices
- Choices about responsibility boundaries in the data model
- Screen flow choices
- Choices about whether to replace an existing system

## Permitted Inferences
- Reusing patterns already in use in the code
- Decomposing a stated policy into implementation units
- Organizing facts that are undocumented but have only a single possible interpretation in the code

## Stop Condition
- When 2 or more different design options are possible but the project documents have no answer
