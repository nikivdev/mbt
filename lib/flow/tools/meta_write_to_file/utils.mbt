///|
/// Generate a diff between old and new content (naive implementation)
/// TODO: replace with more reasonable diff generation (e.g., using git diff)
async fn generate_diff(old_content : String, new_content : String) -> String? {
  if old_content == new_content {
    return None
  }
  Some(@git.generate_git_diff(original=old_content, modified=new_content))
}
