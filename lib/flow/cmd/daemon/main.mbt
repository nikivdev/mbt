///|
priv suberror HttpError {
  HttpError(code~ : Int, reason~ : String, body~ : String)
}

///|
fn json_error(code : Int, reason : String, body : Json) -> HttpError {
  HttpError(code~, reason~, body=body.stringify())
}

///|
fn text_error(code : Int, reason : String, body : String) -> HttpError {
  HttpError(code~, reason~, body~)
}

///|
priv struct Server {
  name : String?
  id : @uuid.Uuid
  cwd : String
  port : Int
}

///|
priv struct Daemon {
  models : @model.Loader
  uuid : @uuid.Generator
  process : @spawn.Manager
  by_cwd : Map[String, Server]
  by_id : Map[@uuid.Uuid, Server]
  register_queues : Map[String, @aqueue.Queue[Int]]
  exec_path : String
  port : Int
}

///|
async fn Daemon::start(self : Daemon) -> Unit {
  self.process.start()
}

///|
async fn run_server(
  port~ : Int,
  f : async (@http.Request, @http.ServerConnection) -> Unit,
) -> Unit {
  let addr = try! @socket.Addr::parse("[::]:\{port}")
  println("[INFO] Starting HTTP server on port \{port}...")
  println("[INFO] Visit http://localhost:\{port}/")
  @http.run_server(addr, (conn, _) => for {
    try {
      let request = conn.read_request()
      println(
        "[INFO] (Daemon) Received request: \{request.meth} \{request.path}",
      )
      f(request, conn)
    } catch {
      HttpError(code~, reason~, body~) =>
        conn
        ..send_response(code, reason, extra_headers={
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, OPTIONS, POST",
          "Access-Control-Allow-Headers": "Content-Type",
        })
        ..write(body)
        ..end_response()
      error => raise error
    }
  })
}

///|
async fn html_read_file(path : String) -> String {
  @fsx.read_file(path) catch {
    @os_error.OSError(_) as os_error if os_error.is_ENOENT() =>
      raise text_error(404, "NotFound", "<h1>404 Not Found</h1>")
    error => raise error
  }
}

///|
priv struct Register {
  id : String
  port : Int
}

///|
async fn Daemon::create_task(
  self : Daemon,
  group~ : @async.TaskGroup[Unit],
  conn : @http.ServerConnection,
) -> Unit {
  let request_bytes = conn.read_all().binary()
  println("[DEBUG] Request body bytes: \{request_bytes}")
  let request_text = @encoding/utf8.decode(request_bytes) catch {
    @encoding/utf8.Malformed(bytes) =>
      raise json_error(
        400,
        "Bad Request",
        "Invalid UTF-8 in request body: \{bytes}",
      )
  }
  println("[DEBUG] Request body text: \{request_text}")
  let request_json = @json.parse(request_text) catch {
    error =>
      raise json_error(
        400,
        "Bad Request",
        "Invalid JSON in request body: \{error}",
      )
  }
  println("[DEBUG] Request body JSON: \{request_json.stringify(indent=2)}")
  guard request_json
    is {
      "name"? : name,
      "model"? : model_name,
      "cwd"? : cwd,
      "message"? : message,
      ..
    } else {
    raise json_error(400, "Bad Request", {
      "error": {
        "code": -1,
        "message": "Missing required fields 'prompt' or 'model'",
      },
    })
  }
  let model_name : String? = model_name.map(model_name => @json.from_json(
    model_name,
  )) catch {
    error =>
      raise json_error(400, "Bad Request", {
        "error": { "code": -1, "message": "Invalid 'model' field: \{error}" },
      })
  }
  guard self.models.get_model(name?=model_name) is Some(model) else {
    raise json_error(404, "Not Found", {
      "error": { "code": -1, "message": "Model not found: \{model_name}" },
    })
  }
  let name : String? = name.map(name => @json.from_json(name)) catch {
    error =>
      raise json_error(400, "Bad Request", {
        "error": { "code": -1, "message": "Invalid 'name' field: \{error}" },
      })
  }
  let message : @openai.ChatCompletionMessageParam? = message.map(message => @json.from_json(
    message,
  )) catch {
    error =>
      raise json_error(400, "Bad Request", {
        "error": { "code": -1, "message": "Invalid 'message' field: \{error}" },
      })
  }
  let cwd = if cwd is Some(cwd) {
    if cwd is String(cwd) {
      cwd
    } else {
      raise json_error(400, "Bad Request", {
        "error": {
          "code": -1,
          "message": "Invalid 'cwd' field: expected string",
        },
      })
    }
  } else {
    @fsx.mkdtemp(@path.join(@os.tmpdir(), "maria-server-task-XXXXXX")) catch {
      error =>
        raise json_error(500, "Internal Server Error", {
          "error": {
            "code": -1,
            "message": "Failed to create temporary working directory: \{error}",
          },
        })
    }
  }
  if self.by_cwd.get(cwd) is Some(server) {
    raise json_error(409, "Conflict", {
      "task": {
        "name": server.name,
        "id": server.id.to_string(),
        "cwd": server.cwd,
        "port": server.port,
      },
    })
  }
  let id = self.uuid.v4()
  let process = self.process.spawn(
    self.exec_path,
    [
      "--model",
      model.name,
      "--port",
      "0",
      "--register-id",
      id.to_string(),
      "--register-host",
      "localhost",
      "--register-port",
      self.port.to_string(),
    ],
    cwd~,
  )
  println(
    "[INFO] Spawned task process with PID \{process.pid} and ID \{id} at '\{cwd}'",
  )
  let register_queue = @aqueue.Queue::new()
  self.register_queues[id.to_string()] = register_queue
  let register_port = @async.with_timeout(5_000, () => register_queue.get()) catch {
    @async.TimeoutError => {
      println("[ERROR] Timed out waiting for task to register after 5 seconds")
      raise json_error(500, "Internal Server Error", {
        "error": {
          "code": -1,
          "message": "Timed out waiting for task to register",
        },
      })
    }
    error => raise error
  }
  println(
    "[INFO] Received registration from task '\{id}' on port \{register_port}",
  )
  let server = Server::{ name, id, cwd, port: register_port }
  group.spawn_bg(() => {
    let exit_code = process.wait()
    if exit_code != 0 {
      println("[ERROR] task process exited with code \{exit_code}")
    }
    self.by_cwd.remove(cwd)
    self.by_id.remove(server.id)
  })
  self.by_cwd[cwd] = server
  self.by_id[server.id] = server
  if message is Some(message) {
    println("[INFO] Write initial messages to task '\{id}'...")
    let (message_response, message_body) = @http.post(
      "http://localhost/v1/message",
      ({ "message": message.to_json() } : Json),
      port=register_port,
    )
    println(
      "[DEBUG] Received message response: \{message_response.code} \{message_response.reason}",
    )
    guard message_response.code is (200..=299) else {
      raise json_error(500, "Internal Server Error", {
        "error": {
          "code": message_response.code,
          "message": "Failed to send initial message to task: \{message_response.code} \{message_response.reason}",
          "metadata": {
            "code": message_response.code,
            "reason": message_response.reason,
            "body": message_body.json(),
          },
        },
      })
    }
  }
  conn.send_response(201, "Created", extra_headers={
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS, POST",
    "Access-Control-Allow-Headers": "Content-Type",
  })
  let body_task : Map[String, Json] = {}
  if server.name is Some(name) {
    body_task["name"] = name.to_json()
  }
  body_task["id"] = server.id.to_string().to_json()
  body_task["cwd"] = server.cwd.to_json()
  body_task["port"] = server.port.to_json()
  let body : Json = { "task": Json::object(body_task) }
  conn.write(body)
  conn.flush()
  conn.end_response()
}

///|
async fn Daemon::list_models(
  self : Daemon,
  conn : @http.ServerConnection,
) -> Unit {
  let models : Array[Json] = []
  for model in self.models.models() {
    models.push({ "name": model.name })
  }
  let response : Json = { "models": models }
  conn
  ..send_response(200, "OK", extra_headers={
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS, POST",
    "Access-Control-Allow-Headers": "Content-Type",
  })
  ..write(response.stringify())
  ..end_response()
}

///|
async fn Daemon::register_task(
  self : Daemon,
  conn : @http.ServerConnection,
) -> Unit {
  let request_bytes = conn.read_all().binary()
  let request_text = @encoding/utf8.decode(request_bytes) catch {
    @encoding/utf8.Malformed(bytes) =>
      raise json_error(
        400,
        "Bad Request",
        "Invalid UTF-8 in request body: \{bytes}",
      )
  }
  let request_json = @json.parse(request_text) catch {
    error =>
      raise json_error(
        400,
        "Bad Request",
        "Invalid JSON in request body: \{error}",
      )
  }
  guard request_json is { "id": id, "port": port, .. } else {
    raise json_error(400, "Bad Request", {
      "error": {
        "code": -1,
        "message": "Missing required fields 'id' or 'port'",
      },
    })
  }
  let id : String = @json.from_json(id) catch {
    error =>
      raise json_error(400, "Bad Request", {
        "error": { "code": -1, "message": "Invalid 'id' field: \{error}" },
      })
  }
  let port : Int = @json.from_json(port) catch {
    error =>
      raise json_error(400, "Bad Request", {
        "error": { "code": -1, "message": "Invalid 'port' field: \{error}" },
      })
  }
  let register : Register = { id, port }
  println("[INFO] Registered task '\{register.id}' on port \{register.port}")
  self.register_queues[id].put(register.port)
  conn.send_response(200, "OK", extra_headers={
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS, POST",
    "Access-Control-Allow-Headers": "Content-Type",
  })
  conn.end_response()
}

///|
async fn Daemon::list_tasks(
  self : Daemon,
  conn : @http.ServerConnection,
) -> Unit {
  let tasks : Array[Json] = []
  for _, server in self.by_cwd {
    tasks.push({
      "name": server.name,
      "id": server.id.to_string(),
      "cwd": server.cwd,
      "port": server.port,
    })
  }
  let response : Json = { "tasks": tasks }
  conn
  ..send_response(200, "OK", extra_headers={
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS, POST",
    "Access-Control-Allow-Headers": "Content-Type",
  })
  ..write(response.stringify())
  ..end_response()
}

///|
async fn Daemon::get_task(
  self : Daemon,
  id : StringView,
  conn : @http.ServerConnection,
) -> Unit {
  guard self.by_id.get(
      @uuid.parse(id) catch {
        _ =>
          raise json_error(400, "Bad Request", {
            "error": { "code": -1, "message": "Invalid UUID: \{id}" },
          })
      },
    )
    is Some(server) else {
    raise json_error(404, "Not Found", {
      "error": { "code": -1, "message": "Task not found: \{id}" },
    })
  }
  let response : Json = {
    "task": {
      "name": server.name,
      "id": server.id.to_string(),
      "cwd": server.cwd,
      "port": server.port,
    },
  }
  conn
  ..send_response(200, "OK", extra_headers={
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS, POST",
    "Access-Control-Allow-Headers": "Content-Type",
  })
  ..write(response.stringify())
  ..end_response()
}

///|
async fn Daemon::listen_task_events(
  self : Daemon,
  id : StringView,
  request : @http.Request,
  conn : @http.ServerConnection,
) -> Unit {
  guard self.by_id.get(
      @uuid.parse(id) catch {
        _ =>
          raise json_error(400, "Bad Request", {
            "error": { "code": -1, "message": "Invalid UUID: \{id}" },
          })
      },
    )
    is Some(server) else {
    raise json_error(404, "Not Found", {
      "error": { "code": -1, "message": "Task not found: \{id}" },
    })
  }
  println("[INFO] Streaming events for task \{id}...")
  let (response, client) = @http.get_stream(
    "http://localhost/v1/events",
    headers=request.headers,
    port=server.port,
    body=conn.read_all(),
  )
  println("[DEBUG] Received response: \{response.code} \{response.reason}")
  conn.send_response(response.code, response.reason, extra_headers={
    "Content-Type": "text/event-stream",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS, POST",
    "Access-Control-Allow-Headers": "Content-Type",
  })
  println("[DEBUG] Streaming response body...")
  conn.write_reader(client)
  println("[DEBUG] Finished streaming response body.")
  conn.end_response()
}

///|
async fn Daemon::list_moonbit_modules(
  self : Daemon,
  id : StringView,
  request : @http.Request,
  conn : @http.ServerConnection,
) -> Unit {
  guard self.by_id.get(
      @uuid.parse(id) catch {
        _ =>
          raise json_error(400, "Bad Request", {
            "error": { "code": -1, "message": "Invalid UUID: \{id}" },
          })
      },
    )
    is Some(server) else {
    raise json_error(404, "Not Found", {
      "error": { "code": -1, "message": "Task not found: \{id}" },
    })
  }
  println("[INFO] Forwarding moonbit modules request to task \{id}...")
  let (response, response_body) = @http.get(
    "http://localhost/v1/moonbit/modules",
    headers=request.headers,
    port=server.port,
    body=conn.read_all(),
  )
  conn.send_response(response.code, response.reason, extra_headers={
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS, POST",
    "Access-Control-Allow-Headers": "Content-Type",
  })
  conn.write(response_body)
  conn.end_response()
}

///|
async fn publish_moonbit_module(conn : @http.ServerConnection) -> Unit {
  let request = conn.read_all().binary()
  let request_text : String = @encoding/utf8.decode(request) catch {
    // TODO(upstream): impl Show for @encoding/utf8.Malformed
    @encoding/utf8.Malformed(bytes) =>
      raise json_error(400, "BadRequest", {
        "error": {
          "code": -1,
          "message": "Invalid UTF-8 in request body: \{bytes}",
        },
      })
  }
  let request_json = @json.parse(request_text) catch {
    error =>
      raise json_error(400, "BadRequest", {
        "error": {
          "code": -1,
          "message": "Invalid JSON in request body: \{error}",
        },
      })
  }
  guard request_json is { "module": { "path": String(path), .. }, .. } else {
    raise json_error(400, "BadRequest", {
      "error": {
        "code": -1,
        "message": "Missing 'module.path' field in request body",
      },
    })
  }
  let process = @spawn.spawn("moon", ["publish"], cwd=path) catch {
    error =>
      raise json_error(500, "InternalServerError", {
        "error": {
          "code": -1,
          "message": "Failed to spawn 'moon publish' for '\{path}': \{error}",
        },
      })
  }
  let module_ = @moon.Module::load(path) catch {
    error =>
      raise json_error(404, "NotFound", {
        "error": {
          "code": -1,
          "message": "No MoonBit module found in path '\{path}': \{error}",
        },
      })
  }
  if process.status == 0 {
    let response : Json = {
      "module": {
        "path": path,
        "name": module_.name,
        "version": module_.version,
        "description": module_.description,
      },
      "process": {
        "status": process.status,
        "stdout": process.stdout,
        "stderr": process.stderr,
      },
    }
    conn
    ..send_response(201, "Created", extra_headers={
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS, POST",
      "Access-Control-Allow-Headers": "Content-Type",
    })
    ..write(response.stringify())
    ..end_response()
  } else {
    let response : Json = {
      "error": {
        "code": -1,
        "message": "Failed to publish module at '\{path}'",
        "metadata": {
          "module": {
            "path": path,
            "name": module_.name,
            "version": module_.version,
            "description": module_.description,
          },
          "process": {
            "status": process.status,
            "stdout": process.stdout,
            "stderr": process.stderr,
          },
        },
      },
    }
    conn
    ..send_response(500, "InternalServerError", extra_headers={
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS, POST",
      "Access-Control-Allow-Headers": "Content-Type",
    })
    ..write(response.stringify())
    ..end_response()
  }
}

///|
async fn Daemon::create_task_message(
  self : Daemon,
  id : StringView,
  request : @http.Request,
  conn : @http.ServerConnection,
) -> Unit {
  guard self.by_id.get(
      @uuid.parse(id) catch {
        _ =>
          raise json_error(400, "Bad Request", {
            "error": { "code": -1, "message": "Invalid UUID: \{id}" },
          })
      },
    )
    is Some(server) else {
    raise json_error(404, "Not Found", {
      "error": { "code": -1, "message": "Task not found: \{id}" },
    })
  }
  println("[INFO] Forwarding message to task \{id}...")
  let (response, response_body) = @http.post(
    "http://localhost/v1/message",
    headers=request.headers,
    port=server.port,
    conn.read_all(),
  )
  conn.send_response(response.code, response.reason, extra_headers={
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS, POST",
    "Access-Control-Allow-Headers": "Content-Type",
  })
  conn.write(response_body)
  conn.end_response()
}

///|
async fn main {
  let args = @os.args()
  let mut port = 8090
  let mut serve = @os.cwd()
  let mut exec_path = None
  loop args[1:] {
    ["-p" | "--port", p, .. args] => {
      port = @strconv.parse_int(p)
      continue args
    }
    ["-s" | "--serve", s, .. args] => {
      serve = if @path.is_absolute(s) { s } else { @path.join(@os.cwd(), s) }
      continue args
    }
    [e, .. args] => {
      exec_path = if @path.is_absolute(e) {
        Some(e)
      } else {
        Some(@path.join(@os.cwd(), e))
      }
      continue args
    }
    [] => break
  }
  guard exec_path is Some(exec_path) else {
    fail("Expected exec path as the first argument")
  }
  if !@fsx.exists(exec_path) {
    fail("Exec path does not exist: \{exec_path}")
  }
  let exec_path = @fsx.resolve(exec_path) catch {
    error => fail("Failed to resolve exec path '\{exec_path}': \{error}")
  }
  let logger = @pino.logger("daemon", @pino.Transport::console())
  let daemon = Daemon::{
    models: @model.Loader::new(home=@os.home(), cwd=@os.cwd(), logger~),
    uuid: @uuid.generator(@rand.chacha8()),
    process: @spawn.Manager::new(cwd=@os.cwd()),
    by_cwd: {},
    by_id: {},
    register_queues: {},
    exec_path,
    port,
  }
  @async.with_task_group(group => {
    group.spawn_bg(() => daemon.start())
    run_server(port~, (request, conn) => {
      let paths = request.path.split("/").collect()
      println("[DEBUG] Handling request paths: \{paths}")
      match (request.meth, paths) {
        // GET /
        (Get, ["", ""]) => {
          let index_html = html_read_file(@path.join(serve, "index.html"))
          conn
          ..send_response(200, "OK", extra_headers={
            "Content-Type": "text/html",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, OPTIONS, POST",
            "Access-Control-Allow-Headers": "Content-Type",
          })
          ..write(index_html)
          ..end_response()
        }
        (Get, ["", "v1", "models"]) => daemon.list_models(conn)
        (Post, ["", "v1", "task", "register"]) => daemon.register_task(conn)
        (Get, ["", "v1", "tasks"]) => daemon.list_tasks(conn)
        (Post, ["", "v1", "task"]) => daemon.create_task(group~, conn)
        (Get, ["", "v1", "task", id]) => daemon.get_task(id, conn)
        (Get, ["", "v1", "task", id, "events"]) =>
          daemon.listen_task_events(id, request, conn)
        (Get, ["", "v1", "task", id, "moonbit", "modules"]) =>
          daemon.list_moonbit_modules(id, request, conn)
        (Post, ["", "v1", "moonbit", "publish"]) => publish_moonbit_module(conn)
        (Post, ["", "v1", "task", id, "message"]) =>
          daemon.create_task_message(id, request, conn)
        (Get, ["", .. file]) =>
          if @path.join(serve, file.join("/")) is path &&
            (try? @fsx.exists_as_file(path)) is Ok(true) {
            let content_type = match @path.ext(path) {
              ".js" => "application/javascript"
              ".css" => "text/css"
              ".html" => "text/html"
              ".png" => "image/png"
              ".jpg" | ".jpeg" => "image/jpeg"
              ".gif" => "image/gif"
              _ => "application/octet-stream"
            }
            println("[DEBUG] Serving static file: \{path}")
            let content = html_read_file(path)
            conn
            ..send_response(200, "OK", extra_headers={
              "Content-Type": content_type,
              "Access-Control-Allow-Origin": "*",
              "Access-Control-Allow-Methods": "GET, OPTIONS, POST",
              "Access-Control-Allow-Headers": "Content-Type",
            })
            ..write(content)
            ..end_response()
          } else {
            raise json_error(404, "NotFound", {
              "error": {
                "code": -1,
                "message": "Unknown endpoint: \{request.path}",
                "metadata": {
                  "method": request.meth.to_string(),
                  "path": request.path,
                },
              },
            })
          }
        _ =>
          raise json_error(404, "NotFound", {
            "error": {
              "code": -1,
              "message": "Unknown endpoint: \{request.path}",
              "metadata": {
                "method": request.meth.to_string(),
                "path": request.path,
              },
            },
          })
      }
    })
  })
}
