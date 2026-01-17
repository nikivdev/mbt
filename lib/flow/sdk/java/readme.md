# Maria Java SDK 🚀

> "Like having a really smart robot helper, but in Java!"

This is the Java version of Maria - an AI agent that can help you with tasks. Don't worry if you've never used Java before, this guide explains everything!

## 🎯 What is This?

Maria is an AI assistant. This Java SDK lets you talk to Maria from your Java programs. Think of it like a toy robot that you can give commands to, and it does things for you!

## 📦 What You Need First

Before we start, you need to install some things on your computer. Think of these as "tools" you need:

### 1. Install Java (The Language)

Java is like the language Maria speaks. You need version 17 or newer.

**On macOS (your computer):**

```bash
# Open your Terminal and type this:
brew install openjdk@17
```

**Check if it worked:**

```bash
java -version
```

You should see something like "17" in the output. If you see an error, Java isn't installed yet!

### 2. Install Maven (The Helper)

Maven is like a helper that downloads libraries and builds your project. Think of it as an assistant that gets all the Lego pieces you need.

**On macOS:**

```bash
brew install maven
```

**Check if it worked:**

```bash
mvn -version
```

You should see some text about Maven version. Success! 🎉

## 🚀 How to Use Maria (The Easy Way)

### Step 1: Try the Example

We made a simple example for you! Let's run it:

```bash
# First, install the maria-java library
mvn clean install

# Go to the examples folder
cd ./examples

# Tell Maven to run the example
mvn compile exec:java
```

That's it! You just talked to Maria! 🎊
