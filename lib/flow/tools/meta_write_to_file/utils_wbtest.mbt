///|
async test "generate_diff with changes" {
  // let old = "line1\nline2\nline3"
  let old =
    #|line1
    #|line2
    #|line3
    #|
  let new =
    #|line1
    #|lineX
    #|line3
    #|line4
    #|
  let diff = generate_diff(old, new)
  inspect(
    diff.unwrap(),
    content=(
      #|diff --git original modified
      #|index 83db48f..beb8b6f 100644
      #|--- original
      #|+++ modified
      #|@@ -1,3 +1,4 @@
      #| line1
      #|-line2
      #|+lineX
      #| line3
      #|+line4
    ),
  )
}
