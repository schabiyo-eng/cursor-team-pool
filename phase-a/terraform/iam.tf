data "aws_iam_policy_document" "worker_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "worker" {
  statement {
    sid       = "ReadServiceAccountKey"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.service_account_key.arn]
  }
}

resource "aws_iam_role" "worker" {
  name_prefix        = "${var.pool_name}-worker-"
  assume_role_policy = data.aws_iam_policy_document.worker_assume.json
}

resource "aws_iam_role_policy" "worker" {
  name   = "read-service-account-key"
  role   = aws_iam_role.worker.id
  policy = data.aws_iam_policy_document.worker.json
}

resource "aws_iam_instance_profile" "worker" {
  name_prefix = "${var.pool_name}-worker-"
  role        = aws_iam_role.worker.name
}
