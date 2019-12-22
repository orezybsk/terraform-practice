data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "ec2_for_ssm" {
  name               = "ec2_for_ssm"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}
data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy_attachment" "ec2_for_ssm" {
  policy_arn = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
  role       = aws_iam_role.ec2_for_ssm.name
}
resource "aws_iam_instance_profile" "ec2_for_ssm" {
  name = "ec2_for_ssm"
  role = aws_iam_role.ec2_for_ssm.name
}
