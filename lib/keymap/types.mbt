///|
/// Declarative keymap system for fish shell integration

///| Action type for key binding
pub enum ActionType {
  Shell      // Execute fish shell command
  Agent      // Invoke hive agent
  Function   // Call fish function
  Command    // Built-in readline command (forward-char, etc)
  Task       // Run flow task
  Keymap     // Switch to another keymap
} derive(Eq, Show)

///| Fish binding modes
pub enum BindMode {
  Default
  Insert
  Normal
  Visual
  Replace
  ReplaceOne
} derive(Eq, Show)

///| Context for when binding is active
pub struct BindContext {
  /// Only active in these directories (glob patterns)
  directories : Array[String]
  /// Only active when these env vars are set
  env_vars : Array[String]
  /// Only active in git repos
  git_repo : Bool?
  /// Only active in specific project types
  project_types : Array[String]
} derive(Eq, Show)

///|
pub fn BindContext::empty() -> BindContext {
  BindContext::{
    directories: [],
    env_vars: [],
    git_repo: None,
    project_types: [],
  }
}

///| Single key binding
pub struct KeyBinding {
  /// Key sequence: "ctrl-a", "alt-x", "ctrl-x ctrl-c"
  keys : String
  /// What type of action
  action_type : ActionType
  /// Target: command string, agent name, function name, task name
  target : String
  /// Human description
  description : String
  /// Binding mode (default if not specified)
  mode : BindMode
  /// Switch to this mode after execution
  sets_mode : BindMode?
  /// When is this binding active
  context : BindContext?
  /// Priority for conflict resolution (higher wins)
  priority : Int
} derive(Eq, Show)

///|
pub fn KeyBinding::new(
  keys : String,
  action_type : ActionType,
  target : String,
) -> KeyBinding {
  KeyBinding::{
    keys,
    action_type,
    target,
    description: "",
    mode: Default,
    sets_mode: None,
    context: None,
    priority: 0,
  }
}

///|
pub fn KeyBinding::with_description(self : KeyBinding, desc : String) -> KeyBinding {
  KeyBinding::{ ..self, description: desc }
}

///|
pub fn KeyBinding::with_mode(self : KeyBinding, mode : BindMode) -> KeyBinding {
  KeyBinding::{ ..self, mode }
}

///|
pub fn KeyBinding::with_priority(self : KeyBinding, priority : Int) -> KeyBinding {
  KeyBinding::{ ..self, priority }
}

///| A group of related bindings
pub struct Keymap {
  name : String
  description : String
  /// Inherit bindings from other keymaps
  extends : Array[String]
  /// The bindings in this keymap
  bindings : Array[KeyBinding]
  /// Is this keymap enabled
  enabled : Bool
  /// Tags for categorization
  tags : Array[String]
} derive(Show)

///|
pub fn Keymap::new(name : String) -> Keymap {
  Keymap::{
    name,
    description: "",
    extends: [],
    bindings: [],
    enabled: true,
    tags: [],
  }
}

///|
pub fn Keymap::add_binding(self : Keymap, binding : KeyBinding) -> Keymap {
  let bindings = self.bindings.copy()
  bindings.push(binding)
  Keymap::{ ..self, bindings }
}

///| Global keymap configuration
pub struct KeymapConfig {
  /// Schema version
  version : Int
  /// All defined keymaps
  keymaps : Array[Keymap]
  /// Currently active keymap name
  active : String
  /// Default mode for new bindings
  default_mode : BindMode
  /// Auto-reload on config change
  auto_reload : Bool
} derive(Show)

///|
pub fn KeymapConfig::new() -> KeymapConfig {
  KeymapConfig::{
    version: 1,
    keymaps: [],
    active: "default",
    default_mode: Default,
    auto_reload: true,
  }
}

///|
pub fn KeymapConfig::with_keymaps(keymaps : Array[Keymap], active : String) -> KeymapConfig {
  KeymapConfig::{
    version: 1,
    keymaps,
    active,
    default_mode: Default,
    auto_reload: true,
  }
}

///| Convert BindMode to fish mode string
pub fn BindMode::to_fish(self : BindMode) -> String {
  match self {
    Default => "default"
    Insert => "insert"
    Normal => "normal"
    Visual => "visual"
    Replace => "replace"
    ReplaceOne => "replace_one"
  }
}

///| Convert ActionType to string
pub fn ActionType::to_string(self : ActionType) -> String {
  match self {
    Shell => "shell"
    Agent => "agent"
    Function => "function"
    Command => "command"
    Task => "task"
    Keymap => "keymap"
  }
}
