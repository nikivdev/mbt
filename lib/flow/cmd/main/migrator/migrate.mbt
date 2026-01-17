///|
priv struct Migrator {
  repo : String
  max_while_loop : Int
}

///|
fn Migrator::parse(args : ArrayView[String]) -> Migrator raise {
  let mut repo : String? = None
  let mut max_while_loop : Int = 1
  loop args {
    ["--repo", value, .. rest] => {
      repo = Some(value)
      continue rest
    }
    ["--max-while-loop", value, .. rest] => {
      max_while_loop = @strconv.parse_int(value)
      continue rest
    }
    [unknown, ..] => raise @argument.InvalidArgument(unknown)
    [] => break
  }
  guard repo is Some(repo) else {
    raise @argument.InvalidArgument("--repo is required")
  }
  Migrator::{ repo, max_while_loop }
}

///|
fn normalize_repo_name(name : StringView) -> String {
  let normalized = StringBuilder::new()
  for char in name {
    if char is ('a'..='z' | 'A'..='Z' | '0'..='9' | '_') {
      normalized.write_char(char)
    } else {
      normalized.write_char('_')
    }
  }
  normalized.to_string()
}

///|
fn get_repo_name(url : String) -> String {
  let name = url.split("/").collect().pop()
  match name {
    Some([.. name, .. ".git"]) => name.to_string()
    Some(name) => name.to_string()
    None => "repository"
  }
}

///|
async fn Migrator::migrate(self : Migrator, cwd~ : String) -> Unit {
  let src_name = get_repo_name(self.repo)
  let dst_name = normalize_repo_name(src_name)
  let dst_path = @path.join(cwd, dst_name)
  let src_path = dst_path
    |> @path.join(".moonagent")
    |> @path.join("repos")
    |> @path.join(src_name)
  for loop_index in 1..=self.max_while_loop {
    if !@fsx.exists(dst_path) {
      @moon.new(name=dst_name, dst_name)
    }
    if !@fsx.exists(src_path) {
      println("cloning repository \{self.repo} into \{src_path}...")
      @git.clone(self.repo, to=src_path, cwd=dst_path)
    }
    println("cloned into \{src_path}")
    let maria = @maria.Maria::new()
    println("Migration attempt #\{loop_index}")
    let prompt =
      $|Using the reference at \{src_path}, migrate the target repository into
      $|the current MoonBit project. Translate file-by-file and preserve original
      $|structure; avoid freeform rewrites.
    maria.start(prompt)
  }
}

///|
pub async fn migrate(args : ArrayView[String]) -> Unit {
  let migrator = Migrator::parse(args)
  let cwd = @os.cwd()
  migrator.migrate(cwd~)
}
