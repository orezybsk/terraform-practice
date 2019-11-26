provider "aws" {
  region = "ap-northeast-1"
}

// IP制限＆MFA強制ポリシー
data "aws_iam_policy_document" "IpRestrictionAndMFAForcePolicy" {
  // IP制限
  statement {
    effect  = "Deny"
    actions = ["*"]
    resources = ["*"]
    condition {
      test     = "NotIpAddress"
      variable = "aws:SourceIp"
      values   = ["60.0.0.0/8"]
    }
  }
  // MFA強制
  statement {
    effect    = "Deny"
    not_actions = ["iam:*"]
    resources = ["*"]
    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = [false]
    }
  }
  // パスワード設定＆MFAデバイス設定許可
  statement {
    effect    = "Allow"
    actions = [
      "iam:ChangePassword",
      "iam:CreateAccessKey",
      "iam:CreateVirtualMFADevice",
      "iam:DeactivateMFADevice",
      "iam:DeleteAccessKey",
      "iam:DeleteVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:GetAccountPasswordPolicy",
      "iam:UpdateAccessKey",
      "iam:UpdateSigningCertificate",
      "iam:UploadSigningCertificate",
      "iam:UpdateLoginProfile",
      "iam:ResyncMFADevice"
    ]
    resources = [
      "arn:aws:iam::*:user/$${aws:username}",
      "arn:aws:iam::*:mfa/$${aws:username}"
    ]
  }
}
resource "aws_iam_policy" "IpRestrictionPolicy" {
  name   = "IpRestrictionPolicy"
  policy = data.aws_iam_policy_document.IpRestrictionAndMFAForcePolicy.json
}

// ReadOnlyグループ
resource "aws_iam_group" "ReadOnlyGroup" {
  name = "ReadOnlyGroup"
}
resource "aws_iam_group_policy_attachment" "ReadOnlyGroup" {
  group      = aws_iam_group.ReadOnlyGroup.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

// サンプルユーザ
resource "aws_iam_user" "SampleUser" {
  name = "SampleUser"
  // MFAデバイスを登録していると削除できないので forace_destroy を true にしている
  force_destroy = true
}
resource "aws_iam_user_login_profile" "SampleUser" {
  user = aws_iam_user.SampleUser.name
  // Terraform＋GPG で IAM User にログインパスワードを設定
  // http://blog.father.gedow.net/2016/12/16/terraform-iam-user-password/
  // を参考にして生成した
  pgp_key = "mQENBF3ZCj0BCADgPabfw1rC8j9pXYyOOrn7E94Ab4fCyEV624FlnhjTa9G/AtAykCWpK2IJEmLK6k/GKC4KI02tlhVew1U6FCqTt3NYi1nnww7H3/bjtIolHqGbT7V3at4Yq2c8y9yH5p1dvXAMuOEfP1MPXyIDT3sPWDmnctNb9vSWvHuzEY+zBah2K7RXo6LZQxIwOHz7NJrZXCHKe93FrdDXnUTaKSLdcv9zL4XGZAM/zjruLan331Bv2j54oxnk47nz749W1MhFF8WIsU42tRZ4DvI8mLbKXRJP3Pg+E90Lq2XmIezRaZHF/x3SXcLXLJw+31uk2+CigwKc/Ds3HcfAouzK1jRXABEBAAG0JFNhbXBsZVVzZXIgPFNhbXBsZVVzZXJAc2FtcGxlLmNvLmpwPokBVAQTAQgAPhYhBJt3akGrjhB/TfDaC/lbGuCOZ/RRBQJd2Qo9AhsDBQkDwmcABQsJCAcCBhUKCQgLAgQWAgMBAh4BAheAAAoJEPlbGuCOZ/RRlo0IAKlRo5lSQT//fIcL8RF+ZkNqJkb8JsjV80hIrhEinN6JVP3s9Js075Xcm9rCvtg3OfQmXdktUkoHYwJLpJmaGtMSdqnHTZI8lnZb09XFLHybsF1CMnb+pATvyhWeRuvQkTL1FZXhZyoFrtMvjGk463grTYRCERFw07SgHBwyM4aS+P5tqpCqxyFb1idkb1NtsEVVWaqKgLpPDF36e5aArQHorBRZ7hU/3de6jKYsjRprhAwPkjB/yGpWHBcMl4I7woY3OBgkgXoegjpb0QsWX/+updpziDVy+QPic5aykJIMdSnXeW4aMp1ojzqHu8qGYEAsqTrk8W4EZmga2KFTjuW5AQ0EXdkKPQEIANShRV55QDLboKCSy8wKnu+iMpSRzglKXeyq8zeRlghLLW/uocgH4p7H28FzPt37Qu8UlhXM86S0nfzp7tT0IVKsvoFmMrYi2T3t4UMNQqRQCXd30qvLIQL+4WIbmI4WSu3kdYlxOofPKbMVuntqjXCkIljpUeRQ4vSW5YGhbr0Amm4h0sdOyCep5yodxLmM28dkWFRGhdNcNyFlv1qkAiFRsXPMzB25oy3zopbzUh4EIWHDDIvWChd+ltVCbVRhBj4vMPKLCeIppGvo5v973x8SfmzkUiPuzX5PJbCf8gjSTb9MLuDVO3rCNy1Bbnazb9tSOccl/r79vd5dnzC5rnMAEQEAAYkBPAQYAQgAJhYhBJt3akGrjhB/TfDaC/lbGuCOZ/RRBQJd2Qo9AhsMBQkDwmcAAAoJEPlbGuCOZ/RRptYH/i92FLPw5faTmqHgqh/mpxVd8/mkrfxOh+vwv9/MSHQpJgRoGWojybnvtjttpWb38xOTzFkAmNGvLsFvIERWPircRH6L7s/uaclZ5CcDHpfXnTCeKVKjsCHZqvX4++WxGXBqALUbzVYcdLVnsgIckKQsQhHGcrzyySbbV/QBIgYsJgnMMs4L/yWbc4T4ymi9aHOnZejwSkhFzIea8a2s6ongntxX98hXWEleo0J8fucRVnzJpXh0QieBVzuE61ochYq9fSeaSMMS9VcpTqsjWu9w84w18Urt+H9yhrZG/OtsbQAV9f1gMBzfvtjaIYvM1wX5zMqowIdNAQ6Zu8SWDns="
}
output "SampleUserPassword" {
  // 表示された文字列を echo <文字列> | base64 -d | gpg -r SampleUser
  // でデコードされたパスワードが表示される
  value = aws_iam_user_login_profile.SampleUser.encrypted_password
}
resource "aws_iam_user_policy_attachment" "AttachIpRestrictionPolicyToSampleUser" {
  user       = aws_iam_user.SampleUser.name
  policy_arn = aws_iam_policy.IpRestrictionPolicy.arn
}
resource "aws_iam_user_group_membership" "AssignSampleUserToReadOnlyGroup" {
  user   = aws_iam_user.SampleUser.name
  groups = [aws_iam_group.ReadOnlyGroup.name]
}

// 管理者ロール
data "aws_iam_policy_document" "AssumeRolePolicy" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.SampleUser.arn]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = [true]
    }
  }
}
resource "aws_iam_role" "AdminRole" {
  name               = "AdminRole"
  assume_role_policy = data.aws_iam_policy_document.AssumeRolePolicy.json
}
resource "aws_iam_role_policy_attachment" "AdminRole" {
  role       = aws_iam_role.AdminRole.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

// SwitchRole許可ポリシー
data "aws_iam_policy_document" "SwitchAdminRolePolicy" {
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.AdminRole.arn]
  }
}
resource "aws_iam_policy" "SwitchAdminRolePolicy" {
  name   = "SwitchAdminRolePolicy"
  policy = data.aws_iam_policy_document.SwitchAdminRolePolicy.json
}
resource "aws_iam_user_policy_attachment" "AttachSwitchAdminRolePolicyToSampleUser" {
  user       = aws_iam_user.SampleUser.name
  policy_arn = aws_iam_policy.SwitchAdminRolePolicy.arn
}

output "arn" {
  value = aws_iam_user.SampleUser.arn
}
