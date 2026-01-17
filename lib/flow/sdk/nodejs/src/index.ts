import { spawn } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { arch, platform } from "node:os";
import { createInterface } from "node:readline";
import { Notification } from "./events";

function getSystem(): string {
  const platformName = platform().toLowerCase();
  const archName = arch().toLowerCase();
  return `${platformName}-${archName}`;
}

export class Maria {
  async *start(prompt: string): AsyncGenerator<Notification, void, unknown> {
    const system = getSystem();

    // Get the path to the bin directory relative to this file
    const __dirname = dirname(fileURLToPath(import.meta.url));
    const executablePath = join(__dirname, "..", "bin", `${system}.exe`);

    const process = spawn(executablePath, ["exec", prompt], {
      stdio: ["ignore", "pipe", "inherit"],
    });

    if (!process.stdout) {
      throw new Error("Failed to spawn Maria process: stdout is null");
    }

    const rl = createInterface({
      input: process.stdout,
      crlfDelay: Infinity,
    });

    for await (const line of rl) {
      if (line.trim()) {
        try {
          const notification: Notification = JSON.parse(line);
          yield notification;
        } catch (error) {
          throw new Error(`Failed to parse notification: ${line}`);
        }
      }
    }

    const exitCode = await new Promise<number | null>((resolve) => {
      process.on("close", resolve);
    });

    if (exitCode !== 0) {
      throw new Error(`Maria process failed with exit code: ${exitCode}`);
    }
  }
}

export * from "./events";
