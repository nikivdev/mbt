let eventSource = null;
const messagesDiv = document.getElementById("messages");
const statusDiv = document.getElementById("status");
const messageInput = document.getElementById("messageInput");
const sendBtn = document.getElementById("sendBtn");
const modulesListDiv = document.getElementById("modulesList");
const refreshModulesBtn = document.getElementById("refreshModulesBtn");

// MoonBit Modules Management
async function loadModules() {
  try {
    modulesListDiv.innerHTML = '<div class="loading">Loading modules...</div>';
    const response = await fetch("/v1/moonbit/modules");

    if (!response.ok) {
      throw new Error(`Failed to load modules: ${response.statusText}`);
    }

    const data = await response.json();
    displayModules(data.modules || []);
  } catch (error) {
    modulesListDiv.innerHTML = `<div class="no-modules">Error: ${escapeHtml(
      error.message
    )}</div>`;
    addMessage(`✗ Failed to load modules: ${error.message}`);
  }
}

function displayModules(modules) {
  if (modules.length === 0) {
    modulesListDiv.innerHTML =
      '<div class="no-modules">No MoonBit modules found in the current directory.</div>';
    return;
  }

  modulesListDiv.innerHTML = modules
    .map(
      (module, index) => `
    <div class="module-item">
      <div class="module-info">
        <div>
          <span class="module-name">${escapeHtml(
            module.name || "Unknown"
          )}</span>
          <span class="module-version">v${escapeHtml(
            module.version || "0.0.0"
          )}</span>
        </div>
        ${
          module.description
            ? `<div class="module-description">${escapeHtml(
                module.description
              )}</div>`
            : ""
        }
        <div class="module-path">${escapeHtml(module.path || "")}</div>
      </div>
      <div class="module-actions">
        <button class="publish-btn" onclick="publishModule('${escapeHtml(
          module.path
        )}', ${index})">
          Publish
        </button>
      </div>
    </div>
  `
    )
    .join("");
}

async function publishModule(modulePath, moduleIndex) {
  const buttons = document.querySelectorAll(".publish-btn");
  const button = buttons[moduleIndex];

  if (!button) return;

  button.disabled = true;
  button.textContent = "Publishing...";

  try {
    const response = await fetch("/v1/moonbit/publish", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        module: {
          path: modulePath,
        },
      }),
    });

    const data = await response.json();

    if (response.ok) {
      addMessage(
        `✓ Successfully published module: ${data.module.name}@${data.module.version}`
      );
      button.textContent = "✓ Published";
      button.style.background = "#45a049";

      // Reset button after 3 seconds
      setTimeout(() => {
        button.textContent = "Publish";
        button.style.background = "";
        button.disabled = false;
      }, 3000);
    } else {
      const errorMsg = data.error?.message || response.statusText;
      addMessage(`✗ Failed to publish module: ${errorMsg}`);

      if (data.error?.metadata?.process) {
        const process = data.error.metadata.process;
        if (process.stderr) {
          addMessage(`stderr: ${process.stderr}`);
        }
      }

      button.textContent = "✗ Failed";
      button.style.background = "#f44336";

      // Reset button after 3 seconds
      setTimeout(() => {
        button.textContent = "Publish";
        button.style.background = "";
        button.disabled = false;
      }, 3000);
    }
  } catch (error) {
    addMessage(`✗ Error publishing module: ${error.message}`);
    button.textContent = "✗ Error";
    button.style.background = "#f44336";

    // Reset button after 3 seconds
    setTimeout(() => {
      button.textContent = "Publish";
      button.style.background = "";
      button.disabled = false;
    }, 3000);
  }
}

refreshModulesBtn.addEventListener("click", loadModules);

// Pretty-print utilities based on cmd/jsonl2md formatting logic
function escapeHtml(text) {
  const div = document.createElement("div");
  div.textContent = text;
  return div.innerHTML;
}

function formatTimestamp(timestamp) {
  if (!timestamp) return "";
  const date = new Date(timestamp);
  return date.toLocaleTimeString();
}

function formatToolCallArguments(name, args) {
  if (args.path) {
    return `<span class="tool-name">&lt;${name} path="${escapeHtml(
      args.path
    )}"&gt;</span>`;
  } else if (args.command) {
    return `<span class="tool-name">&lt;${name} command="${escapeHtml(
      args.command
    )}"&gt;</span>`;
  } else {
    return `<span class="tool-name">&lt;${name}&gt;</span>`;
  }
}

function formatMessageRole(message) {
  if (message.role === "user") return "User";
  if (message.role === "assistant") return "Assistant";
  if (message.role === "system") return "System";
  if (message.role === "tool") return "Tool";
  return message.role;
}

function extractMessageContent(message) {
  if (typeof message.content === "string") {
    return message.content;
  }
  if (Array.isArray(message.content)) {
    return message.content
      .filter((part) => part.type === "text")
      .map((part) => part.text)
      .join("");
  }
  return "";
}

function formatLogEntry(data) {
  const timestamp = data.time ? formatTimestamp(data.time) : "";

  // Handle different message types
  switch (data.msg) {
    case "ModelLoaded": {
      const modelName = Array.isArray(data.name) ? data.name[0] : data.name;
      return `
        <div class="log-entry model-loaded">
          <div class="log-header">
            <span class="log-type">System Information</span>
            ${timestamp ? `<span class="timestamp">${timestamp}</span>` : ""}
          </div>
          <div class="log-content">Model: ${escapeHtml(modelName)}</div>
        </div>
      `;
    }

    case "MessageAdded": {
      const message = data.message;
      const role = formatMessageRole(message);
      const content = extractMessageContent(message).trim();
      const firstLine = content.split("\n").find((line) => line.trim());
      const title = firstLine ? `${role}: ${firstLine}` : role;

      // System messages are collapsed by default, others are open
      const isOpen = message.role !== "system";

      return `
        <div class="log-entry message-added">
          <div class="log-header">
            <span class="log-type">${escapeHtml(title)}</span>
            ${timestamp ? `<span class="timestamp">${timestamp}</span>` : ""}
          </div>
          ${
            content
              ? `<div class="log-content">
                  <details ${isOpen ? "open" : ""}>
                    <summary>Show content</summary>
                    <pre>${escapeHtml(content)}</pre>
                  </details>
                </div>`
              : ""
          }
        </div>
      `;
    }

    case "RequestCompleted": {
      const message = data.message;
      const content = (message.content || "").trim();
      const firstLine = content.split("\n").find((line) => line.trim());
      const title = firstLine ? `Assistant: ${firstLine}` : "Assistant";

      let toolCallsHtml = "";
      if (message.tool_calls && message.tool_calls.length > 0) {
        toolCallsHtml = message.tool_calls
          .map((toolCall) => {
            const args = JSON.parse(toolCall.function.arguments || "{}");
            return `
            <div class="tool-call">
              <div class="tool-header">
                ${formatToolCallArguments(toolCall.function.name, args)}
              </div>
              <details>
                <summary>Show arguments</summary>
                <pre class="tool-args">${escapeHtml(
                  JSON.stringify(args, null, 2)
                )}</pre>
              </details>
            </div>
          `;
          })
          .join("");
      }

      return `
        <div class="log-entry request-completed">
          <div class="log-header">
            <span class="log-type">${escapeHtml(title)}</span>
            ${timestamp ? `<span class="timestamp">${timestamp}</span>` : ""}
          </div>
          ${
            content
              ? `<div class="log-content">
                  <details open>
                    <summary>Show content</summary>
                    <pre>${escapeHtml(content)}</pre>
                  </details>
                </div>`
              : ""
          }
          ${toolCallsHtml}
        </div>
      `;
    }

    case "PostToolCall": {
      const name = data.name;
      const text = data.text || "";
      const hasError = data.error !== undefined;
      const hasResult = data.result !== undefined;

      let titlePrefix = "Tool call result";
      if (hasError) {
        titlePrefix = "❌ Tool call error";
      }

      let titleSuffix = `&lt;${name}&gt;`;
      if (hasResult && data.result) {
        const result = data.result;
        if (
          name === "execute_command" &&
          Array.isArray(result) &&
          result[0] === "Completed"
        ) {
          const cmdInfo = result[1];
          if (cmdInfo && cmdInfo.command) {
            titleSuffix = `&lt;${name} command="${escapeHtml(
              cmdInfo.command
            )}"&gt;`;
          }
          if (cmdInfo && cmdInfo.status !== 0) {
            titlePrefix = "❌ Tool call error";
          }
        } else if (result.path) {
          titleSuffix = `&lt;${name} path="${escapeHtml(result.path)}"&gt;`;
        }
      }

      return `
        <div class="log-entry post-tool-call ${hasError ? "error" : ""}">
          <div class="log-header">
            <span class="log-type">${titlePrefix}: ${titleSuffix}</span>
            ${timestamp ? `<span class="timestamp">${timestamp}</span>` : ""}
          </div>
          <div class="log-content">
            <details open>
              <summary>Output</summary>
              <pre class="tool-output">${escapeHtml(text)}</pre>
            </details>
          </div>
        </div>
      `;
    }

    default:
      return `
        <div class="log-entry generic">
          <div class="log-header">
            <span class="log-type">${escapeHtml(data.msg || "Unknown")}</span>
            ${timestamp ? `<span class="timestamp">${timestamp}</span>` : ""}
          </div>
          <div class="log-content">
            <details>
              <summary>Show details</summary>
              <pre>${escapeHtml(JSON.stringify(data, null, 2))}</pre>
            </details>
          </div>
        </div>
      `;
  }
}

function addMessage(text, type = "info") {
  const msg = document.createElement("div");
  msg.className = "message";
  const time = new Date().toLocaleTimeString();
  msg.innerHTML = `<span class="time">[${time}]</span> ${text}`;
  messagesDiv.appendChild(msg);
  messagesDiv.scrollTop = messagesDiv.scrollHeight;
}

function connect() {
  eventSource = new EventSource("/v1/events");

  eventSource.onopen = () => {
    statusDiv.textContent = "Status: Connected";
    statusDiv.style.color = "green";
    addMessage("✓ Connected to server");
  };

  eventSource.onmessage = (event) => {
    addMessage("📨 " + event.data);
  };

  eventSource.addEventListener("maria", (event) => {
    const data = JSON.parse(event.data);
    if (data.msg === "TokenCounted") {
      // There are too many of these events; ignore them to reduce noise
      return;
    }
    const formattedHtml = formatLogEntry(data);
    const logDiv = document.createElement("div");
    logDiv.innerHTML = formattedHtml;
    messagesDiv.appendChild(logDiv);
    messagesDiv.scrollTop = messagesDiv.scrollHeight;
  });

  eventSource.onerror = (error) => {
    statusDiv.textContent = "Status: Error/Disconnected";
    statusDiv.style.color = "red";
    addMessage("✗ Connection error");
  };
}

sendBtn.addEventListener("click", async () => {
  const message = messageInput.value.trim();
  if (!message) {
    addMessage("⚠ Please enter a message");
    return;
  }

  try {
    const response = await fetch("/v1/message", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          role: "user",
          content: message,
        },
      }),
    });

    if (response.ok) {
      addMessage(`✓ Sent: ${message}`);
      messageInput.value = "";
    } else {
      addMessage(`✗ Failed to send message: ${response.statusText}`);
    }
  } catch (error) {
    addMessage(`✗ Error: ${error.message}`);
  }
});

messageInput.addEventListener("keypress", (e) => {
  if (e.key === "Enter") {
    sendBtn.click();
  }
});

// Auto-connect when DOM is fully loaded
document.addEventListener("DOMContentLoaded", () => {
  connect();
  loadModules();
});
