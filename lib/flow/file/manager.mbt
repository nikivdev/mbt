///|
pub struct Manager {
  cwd : String
  access : Map[String, Int64]
}

///|
pub fn manager(cwd~ : String) -> Manager {
  Manager::{ cwd, access: {} }
}
