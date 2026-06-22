## Maven Stack

- Build tool: Maven.
- Default verification commands: `mvn test`, `mvn verify`.
- Use `mvn clean verify` only when the target project explicitly documents or requests a clean rebuild.
- `mvn deploy` requires explicit approval because it may publish artifacts to remote repositories.
