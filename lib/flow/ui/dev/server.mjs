import express from "express";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import readline from "readline";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 3001;

// Enable CORS for development
app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.header("Access-Control-Allow-Headers", "Content-Type");
  next();
});

app.post("/v1/message", (req, res) => {
  res.writeHead(200, "OK");
  res.end();
});

// Server-Sent Events endpoint
app.get("/v1/events", async (req, res) => {
  // Set headers for SSE
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.setHeader("X-Accel-Buffering", "no"); // Disable buffering in nginx

  // Send initial connection message
  res.write(
    'event: maria\ndata: {"type":"connected","timestamp":' +
      Date.now() +
      "}\n\n",
  );

  const logFilePath = path.join(__dirname, "log.jsonl");

  try {
    // Check if file exists
    if (!fs.existsSync(logFilePath)) {
      res.write(
        'event: maria\ndata: {"type":"error","message":"Log file not found"}\n\n',
      );
      return;
    }

    // Create readline interface to read line by line
    const fileStream = fs.createReadStream(logFilePath);
    const rl = readline.createInterface({
      input: fileStream,
      crlfDelay: Infinity,
    });

    let lineCount = 0;

    // Read and send each line
    for await (const line of rl) {
      if (line.trim()) {
        try {
          // Validate JSON
          JSON.parse(line);

          // Send the event
          res.write(`event: maria\ndata: ${line}\n\n`);
          lineCount++;

          // Small delay to simulate streaming (optional, can be removed for faster streaming)
          await new Promise((resolve) => setTimeout(resolve, 10));
        } catch (parseError) {
          console.error("Invalid JSON line:", parseError.message);
        }
      }
    }

    console.log(`Sent ${lineCount} events`);

    // Send completion event
    res.write(
      'event: maria\ndata: {"type":"completed","count":' + lineCount + "}\n\n",
    );
  } catch (error) {
    console.error("Error reading log file:", error);
    res.write(
      'event: maria\ndata: {"type":"error","message":"' +
        error.message +
        '"}\n\n',
    );
  }

  // Handle client disconnect
  req.on("close", () => {
    console.log("Client disconnected");
  });
});

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({ status: "ok", timestamp: Date.now() });
});

// Start server
app.listen(PORT, () => {
  console.log(`Dev API server running on http://localhost:${PORT}`);
  console.log(`Events endpoint: http://localhost:${PORT}/events`);
});
