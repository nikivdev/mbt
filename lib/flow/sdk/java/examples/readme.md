# Maria Java Examples

This folder contains example programs showing how to use the Maria Java SDK.

## Quick Start

Run the example:

```bash
cd examples
mvn compile exec:java
```

## What's Inside

- `Main.java` - A simple example that talks to Maria
- `pom.xml` - Maven configuration (tells Maven how to build the project)

## Modifying the Example

Open `Main.java` and change this line:

```java
for (Notification event : maria.start("Hello?")) {
```

Replace `"Hello?"` with your own question or task!

## Common Tasks

### Compile the code

```bash
mvn compile
```

### Run the program

```bash
mvn exec:java
```

### Clean up build files

```bash
mvn clean
```

### Build everything fresh

```bash
mvn clean compile
```

## Tips

- Each time you change `Main.java`, run `mvn compile` before running
- If you get errors, check that Java 17+ is installed: `java -version`
- Check that Maven is installed: `mvn -version`
