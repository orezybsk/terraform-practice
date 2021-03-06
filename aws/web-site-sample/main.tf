provider "aws" {
  region = "ap-northeast-1"
}

///////////////////////////////////////////////////////////////////////////////
// IAM
//
data "aws_iam_policy_document" "allow_describe_regions" {
  statement {
    effect    = "Allow"
    actions   = ["ec2:DescribeRegions"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "example" {
  name   = "example"
  policy = data.aws_iam_policy_document.allow_describe_regions.json
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    // principals の書き方は
    // IAM JSON ポリシーエレメントのリファレンス
    // https://docs.aws.amazon.com/ja_jp/IAM/latest/UserGuide/reference_policies_elements.html
    // の中の「AWS JSON ポリシーの要素:Principal」参照
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "example" {
  name               = "example"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "example" {
  role       = aws_iam_role.example.name
  policy_arn = aws_iam_policy.example.arn
}

module "describe_regions_for_ec2" {
  source     = "./module/iam_role"
  name       = "describe-regions-for-ec2"
  identifier = "ec2.amazonaws.com"
  policy     = data.aws_iam_policy_document.allow_describe_regions.json
}

///////////////////////////////////////////////////////////////////////////////
// S3
//
resource "aws_s3_bucket" "private" {
  bucket = "private-pragmatic-terraform-orezybsk"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "private" {
  bucket                  = aws_s3_bucket.private.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "public" {
  bucket = "public-pragmatic-terraform-orezybsk"
  acl    = "public-read"

  cors_rule {
    allowed_origins = ["https://orezybsk.com"]
    allowed_methods = ["GET"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket" "alb_log" {
  bucket = "alb-log-pragmatic-terraform-orezybsk"
  // alb を作成するとログファイルが作成されて destroy 出来なくなるので
  // force_destroy を true にしておく
  force_destroy = true

  lifecycle_rule {
    enabled = false

    expiration {
      days = "180"
    }
  }
}

resource "aws_s3_bucket_policy" "alb_log" {
  bucket = aws_s3_bucket.alb_log.id
  policy = data.aws_iam_policy_document.alb_log.json
}

data "aws_iam_policy_document" "alb_log" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.alb_log.id}/*"]

    // 582318560864 は
    // ap-northeast-1 の Elastic Load Balancing アカウント ID
    // 以下のページ参照
    // Classic Load Balancer のアクセスログの有効化
    // https://docs.aws.amazon.com/ja_jp/elasticloadbalancing/latest/classic/enable-access-logs.html
    principals {
      type        = "AWS"
      identifiers = ["582318560864"]
    }
  }
}

///////////////////////////////////////////////////////////////////////////////
// VPC, Subnet, EIP, NAT Gateway, Security Group
//
resource "aws_vpc" "example" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "example"
  }
}

// パブリックネットワーク
resource "aws_subnet" "public_0" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1b"
}
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1c"
}

resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route_table" "public_0" {
  vpc_id = aws_vpc.example.id
}
resource "aws_route_table" "public_1" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route" "public_0" {
  route_table_id         = aws_route_table.public_0.id
  gateway_id             = aws_internet_gateway.example.id
  destination_cidr_block = "0.0.0.0/0"
}
resource "aws_route" "public_1" {
  route_table_id         = aws_route_table.public_1.id
  gateway_id             = aws_internet_gateway.example.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "public_0" {
  subnet_id      = aws_subnet.public_0.id
  route_table_id = aws_route_table.public_0.id
}
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_1.id
}

// プライベートネットワーク
resource "aws_subnet" "private_0" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.65.0/24"
  availability_zone       = "ap-northeast-1b"
  map_public_ip_on_launch = false
}
resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.66.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false
}

resource "aws_route_table" "private_0" {
  vpc_id = aws_vpc.example.id
}
resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route_table_association" "private_0" {
  subnet_id      = aws_subnet.private_0.id
  route_table_id = aws_route_table.private_0.id
}
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}

resource "aws_route" "private_0" {
  route_table_id         = aws_route_table.private_0.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_0.id
  destination_cidr_block = "0.0.0.0/0"
}
resource "aws_route" "private_1" {
  route_table_id         = aws_route_table.private_1.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_1.id
  destination_cidr_block = "0.0.0.0/0"
}

// EIP, NAT Gateway
resource "aws_eip" "nat_gateway_0" {
  vpc        = true
  depends_on = [aws_internet_gateway.example]
}
resource "aws_eip" "nat_gateway_1" {
  vpc        = true
  depends_on = [aws_internet_gateway.example]
}

resource "aws_nat_gateway" "nat_gateway_0" {
  allocation_id = aws_eip.nat_gateway_0.id
  subnet_id     = aws_subnet.public_0.id
  depends_on    = [aws_internet_gateway.example]
}
resource "aws_nat_gateway" "nat_gateway_1" {
  allocation_id = aws_eip.nat_gateway_1.id
  subnet_id     = aws_subnet.public_1.id
  depends_on    = [aws_internet_gateway.example]
}

// Security Group
//module "example_sg" {
//  source      = "./module/security_group"
//  name        = "module-sg"
//  vpc_id      = aws_vpc.example.id
//  port        = 80
//  cidr_blocks = ["0.0.0.0/0"]
//}

///////////////////////////////////////////////////////////////////////////////
// ALB
//
module "http_sg" {
  source      = "./module/security_group"
  name        = "http_sg"
  vpc_id      = aws_vpc.example.id
  port        = 80
  cidr_blocks = ["0.0.0.0/0"]
}

module "https_sg" {
  source      = "./module/security_group"
  name        = "https_sg"
  vpc_id      = aws_vpc.example.id
  port        = 443
  cidr_blocks = ["0.0.0.0/0"]
}

module "http_redirect_sg" {
  source      = "./module/security_group"
  name        = "http_redirect_sg"
  vpc_id      = aws_vpc.example.id
  port        = 8080
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_alb" "example" {
  name                       = "example"
  internal                   = false
  idle_timeout               = 60
  enable_deletion_protection = false

  subnets = [
    aws_subnet.public_0.id,
    aws_subnet.public_1.id
  ]

  access_logs {
    bucket  = aws_s3_bucket.alb_log.id
    enabled = true
  }

  security_groups = [
    module.http_sg.security_group_id,
    module.https_sg.security_group_id,
    module.http_redirect_sg.security_group_id
  ]
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_alb.example.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "これは『HTTP』です"
      status_code  = 200
    }
  }
}

resource "aws_alb_listener" "https" {
  load_balancer_arn = aws_alb.example.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.example.arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  // 下に記述した aws_alb_listener_rule により
  // default_action の動きにはならない
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "これは『HTTPS』です"
      status_code  = 200
    }
  }
}

resource "aws_alb_listener" "redirect_http_to_https" {
  load_balancer_arn = aws_alb.example.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_alb_target_group" "example" {
  name                 = "example"
  target_type          = "ip"
  vpc_id               = aws_vpc.example.id
  port                 = 80
  protocol             = "HTTP"
  deregistration_delay = 300

  health_check {
    path                = "/"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = 200
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  depends_on = [aws_alb.example]
}

resource "aws_alb_listener_rule" "example" {
  listener_arn = aws_alb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.example.arn
  }

  condition {
    field  = "path-pattern"
    values = ["/*"]
  }
}

output "alb_dns_name" {
  value = aws_alb.example.dns_name
}

///////////////////////////////////////////////////////////////////////////////
// Route 53
//
variable "domain_name" {}

data "aws_route53_zone" "example" {
  name = var.domain_name
}

resource "aws_route53_record" "example" {
  name    = data.aws_route53_zone.example.name
  zone_id = data.aws_route53_zone.example.zone_id
  type    = "A"

  alias {
    name                   = aws_alb.example.dns_name
    zone_id                = aws_alb.example.zone_id
    evaluate_target_health = true
  }
}

output "domain_name" {
  value = aws_route53_record.example.name
}

///////////////////////////////////////////////////////////////////////////////
// ACM
//
resource "aws_acm_certificate" "example" {
  domain_name               = aws_route53_record.example.name
  subject_alternative_names = []
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "example_certificate" {
  name    = aws_acm_certificate.example.domain_validation_options[0].resource_record_name
  type    = aws_acm_certificate.example.domain_validation_options[0].resource_record_type
  records = [aws_acm_certificate.example.domain_validation_options[0].resource_record_value]
  zone_id = data.aws_route53_zone.example.id
  ttl     = 60
}

resource "aws_acm_certificate_validation" "example" {
  certificate_arn         = aws_acm_certificate.example.arn
  validation_record_fqdns = [aws_route53_record.example_certificate.fqdn]
}

///////////////////////////////////////////////////////////////////////////////
// ECS
//
resource "aws_ecs_cluster" "example" {
  name = "example"
}

// Amazon ECS タスク定義 - タスク定義パラメータ
// https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/task_definition_parameters.html
resource "aws_ecs_task_definition" "example" {
  family                   = "example"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions    = file("./container_definitions.json")
  execution_role_arn       = module.ecs_task_execution_role.iam_role_arn
}

resource "aws_ecs_service" "example" {
  name            = "example"
  cluster         = aws_ecs_cluster.example.arn
  task_definition = aws_ecs_task_definition.example.arn
  desired_count   = 2
  launch_type     = "FARGATE"
  // AWS Fargate プラットフォームのバージョン
  // https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/platform_versions.html
  platform_version                  = "1.3.0"
  health_check_grace_period_seconds = 60

  network_configuration {
    assign_public_ip = false
    security_groups  = [module.nginx_sg.security_group_id]

    subnets = [
      aws_subnet.private_0.id,
      aws_subnet.private_1.id
    ]
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.example.arn
    container_name   = "example"
    container_port   = 80
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}

module "nginx_sg" {
  source      = "./module/security_group"
  name        = "nginx-sg"
  vpc_id      = aws_vpc.example.id
  port        = 80
  cidr_blocks = [aws_vpc.example.cidr_block]
}

resource "aws_cloudwatch_log_group" "for_ecs" {
  name              = "/ecs/example"
  retention_in_days = 1
}

data "aws_iam_policy" "ecs_task_execution_role_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_task_execution" {
  source_json = data.aws_iam_policy.ecs_task_execution_role_policy.policy

  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameters", "kms:Decrypt"]
    resources = ["*"]
  }
}

module "ecs_task_execution_role" {
  source     = "./module/iam_role"
  name       = "ecs-task-execution"
  identifier = "ecs-tasks.amazonaws.com"
  policy     = data.aws_iam_policy_document.ecs_task_execution.json
}

///////////////////////////////////////////////////////////////////////////////
// ECS Scheduled Tasks
//
resource "aws_cloudwatch_log_group" "for_ecs_scheduled_tasks" {
  name              = "/ecs-scheduled-tasks/example"
  retention_in_days = 1
}

resource "aws_ecs_task_definition" "example_batch" {
  family                   = "example-batch"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions    = file("./batch_container_definition.json")
  execution_role_arn       = module.ecs_task_execution_role.iam_role_arn
}

module "ecs_events_role" {
  source     = "./module/iam_role"
  name       = "ecs-events"
  identifier = "events.amazonaws.com"
  policy     = data.aws_iam_policy.ecs_events_role_policy.policy
}

data "aws_iam_policy" "ecs_events_role_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"
}

resource "aws_cloudwatch_event_rule" "example_batch" {
  name                = "example-batch"
  description         = "とても重量なバッチ処理です"
  schedule_expression = "cron(*/2 * * * ? *)"
}

resource "aws_cloudwatch_event_target" "example_batch" {
  target_id = "example-batch"
  rule      = aws_cloudwatch_event_rule.example_batch.name
  role_arn  = module.ecs_events_role.iam_role_arn
  arn       = aws_ecs_cluster.example.arn

  ecs_target {
    launch_type         = "FARGATE"
    task_count          = 1
    platform_version    = "1.3.0"
    task_definition_arn = aws_ecs_task_definition.example_batch.arn

    network_configuration {
      assign_public_ip = "false"
      subnets          = [aws_subnet.private_0.id]
    }
  }
}

///////////////////////////////////////////////////////////////////////////////
// 鍵管理
//
resource "aws_kms_key" "examle" {
  description             = "Example Customer Master Key"
  enable_key_rotation     = true
  is_enabled              = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "example" {
  name          = "alias/example"
  target_key_id = aws_kms_key.examle.key_id
}

///////////////////////////////////////////////////////////////////////////////
// SSMパラメータストア
//
resource "aws_ssm_parameter" "db_username" {
  name        = "/db/username"
  value       = "root"
  type        = "String"
  description = "データベースのユーザー名"
}

resource "aws_ssm_parameter" "db_raw_password" {
  name        = "/db/raw_password"
  value       = "VeryStrongPassword"
  type        = "SecureString"
  description = "データベースのパスワード"
}

// aws ssm put-parameter --name '/db/password' --type 'SecureString' --value 'ModifiedStrongPassword!' --overwrite
resource "aws_ssm_parameter" "db_password" {
  name        = "/db/password"
  value       = "uninitialized"
  type        = "SecureString"
  description = "データベースのパスワード"

  lifecycle {
    ignore_changes = [value]
  }
}

///////////////////////////////////////////////////////////////////////////////
// RDS
//
resource "aws_db_parameter_group" "example" {
  name   = "example"
  family = "mysql5.7"

  parameter {
    name  = "character_set_database"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }
}

resource "aws_db_option_group" "example" {
  name                 = "example"
  engine_name          = "mysql"
  major_engine_version = "5.7"

  option {
    option_name = "MARIADB_AUDIT_PLUGIN"
  }
}

resource "aws_db_subnet_group" "example" {
  name       = "example"
  subnet_ids = [aws_subnet.private_0.id, aws_subnet.private_1.id]
}

resource "aws_db_instance" "example" {
  identifier = "example"
  engine     = "mysql"
  // Amazon RDS での MySQL のバージョン
  // https://docs.aws.amazon.com/ja_jp/AmazonRDS/latest/UserGuide/CHAP_MySQL.html#MySQL.Concepts.VersionMgmt
  engine_version = "5.7.26"
  // DB インスタンスクラスの選択
  // https://docs.aws.amazon.com/ja_jp/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html
  instance_class        = "db.t3.small"
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.examle.arn
  username              = "admin"
  // インスタンス作成後に以下のコマンドを実行してパスワードを変更する
  // aws rds modify-db-instance --db-instance-identifier 'example' --master-user-password 'NewMasterPassword!'
  password                   = "VeryStrongPassword"
  multi_az                   = true
  publicly_accessible        = false
  backup_window              = "09:10-09:40"
  backup_retention_period    = 30
  maintenance_window         = "mon:10:10-mon:10:40"
  auto_minor_version_upgrade = false
  // deletion_protection        = true

  // skip_final_snapshot       = false
  skip_final_snapshot       = true
  final_snapshot_identifier = "example"

  port                   = 3306
  apply_immediately      = false
  vpc_security_group_ids = [module.mysql_sg.security_group_id]
  parameter_group_name   = aws_db_parameter_group.example.name
  option_group_name      = aws_db_option_group.example.name
  db_subnet_group_name   = aws_db_subnet_group.example.name

  lifecycle {
    ignore_changes = [password]
  }
}

module "mysql_sg" {
  source      = "./module/security_group"
  name        = "mysql-sg"
  vpc_id      = aws_vpc.example.id
  port        = 3306
  cidr_blocks = [aws_vpc.example.cidr_block]
}

///////////////////////////////////////////////////////////////////////////////
// ElastiCache
//
// Redis 固有のパラメータ
// https://docs.aws.amazon.com/ja_jp/AmazonElastiCache/latest/red-ug/ParameterGroups.Redis.html
resource "aws_elasticache_parameter_group" "example" {
  name   = "example"
  family = "redis5.0"

  parameter {
    name  = "cluster-enabled"
    value = "no"
  }
}

resource "aws_elasticache_subnet_group" "example" {
  name       = "example"
  subnet_ids = [aws_subnet.private_0.id, aws_subnet.private_1.id]
}

resource "aws_elasticache_replication_group" "example" {
  replication_group_id          = "example"
  replication_group_description = "Cluster Disabled"
  engine                        = "redis"
  // サポートされる Redis 用 ElastiCache バージョン
  // https://docs.aws.amazon.com/ja_jp/AmazonElastiCache/latest/red-ug/supported-engine-versions.html
  engine_version        = "5.0.5"
  number_cache_clusters = 3
  // Amazon ElastiCache の料金
  // https://aws.amazon.com/jp/elasticache/pricing/?nc=sn&loc=4
  // 旧世代のキャッシュノード
  // https://aws.amazon.com/jp/elasticache/previous-generation/
  node_type                  = "cache.m3.medium"
  snapshot_window            = "09:10-10:10"
  snapshot_retention_limit   = 7
  maintenance_window         = "mon:10:10-mon:11:40"
  automatic_failover_enabled = true
  port                       = 6379
  apply_immediately          = false
  security_group_ids         = [module.redis_sg.security_group_id]
  parameter_group_name       = aws_elasticache_parameter_group.example.name
  subnet_group_name          = aws_elasticache_subnet_group.example.name
}

module "redis_sg" {
  source      = "./module/security_group"
  name        = "redis-sg"
  vpc_id      = aws_vpc.example.id
  port        = 6379
  cidr_blocks = [aws_vpc.example.cidr_block]
}

///////////////////////////////////////////////////////////////////////////////
// SSHレスオペレーション
//
// (オプション) AWS CLI 用の Session Manager Plugin をインストールする
// https://docs.aws.amazon.com/ja_jp/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
//
data "aws_iam_policy" "ec2_for_ssm" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "ec2_for_ssm" {
  source_json = data.aws_iam_policy.ec2_for_ssm.policy

  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "s2:PutObject",
      "logs:PutLogEvents",
      "logs:CreateLogStream",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "kms:Decrypt"
    ]
  }
}

module "ec2_for_ssm_role" {
  source     = "./module/iam_role"
  name       = "ec2-for-ssm"
  identifier = "ec2.amazonaws.com"
  policy     = data.aws_iam_policy_document.ec2_for_ssm.json
}

resource "aws_iam_instance_profile" "ec2_for_ssm" {
  name = "ec2-for-ssm"
  role = module.ec2_for_ssm_role.iam_role_name
}

// filter の指定条件は
// https://docs.aws.amazon.com/ja_jp/AWSEC2/latest/UserGuide/finding-an-ami.html
// の「例: 現在の Amazon Linux 2 AMI を検索する」参照。
data "aws_ami" "recent_amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.????????-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "example_for_operation" {
  ami                  = data.aws_ami.recent_amazon_linux_2.image_id
  instance_type        = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_for_ssm.name
  subnet_id            = aws_subnet.private_0.id
  user_data            = file("./user_data.sh")
}

output "operation_instance_id" {
  value = aws_instance.example_for_operation.id
}

resource "aws_s3_bucket" "operation" {
  bucket = "operation-pragmatic-terraformx"

  lifecycle_rule {
    enabled = true
    expiration {
      days = "180"
    }
  }
}

resource "aws_cloudwatch_log_group" "operation" {
  name              = "/operation"
  retention_in_days = 180
}

resource "aws_ssm_document" "session_manager_run_shell" {
  name            = "SSM-SessionManagerRunShell"
  document_type   = "Session"
  document_format = "JSON"

  content = <<EOF
  {
    "schemaVersion": "1.0",
    "description": "Document to hold regional settings for Session Manager",
    "sessionType": "Standard_Stream",
    "inputs": {
      "s3BucketName": "${aws_s3_bucket.operation.id}",
      "cloudWatchLogGroupName": "${aws_cloudwatch_log_group.operation.name}"
    }
  }
EOF
}

///////////////////////////////////////////////////////////////////////////////
// CloudWatch logs --> Kinesis Data Firehose --> S3
//
resource "aws_s3_bucket" "cloudwatch_logs" {
  bucket = "cloudwatch-logs-pragmatic-terraformx"

  lifecycle_rule {
    enabled = true

    expiration {
      days = "180"
    }
  }
}

data "aws_iam_policy_document" "kinesis_data_firehose" {
  statement {
    effect = "Allow"

    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${aws_s3_bucket.cloudwatch_logs.id}",
      "arn:aws:s3:::${aws_s3_bucket.cloudwatch_logs.id}/*",
    ]
  }
}

module "kinesis_data_firehose_role" {
  source     = "./module/iam_role"
  name       = "kinesis-data-firehose"
  identifier = "firehose.amazonaws.com"
  policy     = data.aws_iam_policy_document.kinesis_data_firehose.json
}

resource "aws_kinesis_firehose_delivery_stream" "example" {
  name        = "example"
  destination = "s3"

  s3_configuration {
    role_arn   = module.kinesis_data_firehose_role.iam_role_arn
    bucket_arn = aws_s3_bucket.cloudwatch_logs.arn
    prefix     = "ecs-scheduled-tasks/example/"
  }
}

data "aws_iam_policy_document" "cloudwatch_logs" {
  statement {
    effect    = "Allow"
    actions   = ["firehose:*"]
    resources = ["arn:aws:firehose:ap-northeast-1:*:*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::*:role/cloudwatch-logs"]
  }
}

module "cloudwatch_logs_role" {
  source     = "./module/iam_role"
  name       = "cloudwatch-logs"
  identifier = "logs.ap-northeast-1.amazonaws.com"
  policy     = data.aws_iam_policy_document.cloudwatch_logs.json
}

resource "aws_cloudwatch_log_subscription_filter" "example" {
  name            = "example"
  log_group_name  = aws_cloudwatch_log_group.for_ecs_scheduled_tasks.name
  destination_arn = aws_kinesis_firehose_delivery_stream.example.arn
  filter_pattern  = "[]"
  role_arn        = module.cloudwatch_logs_role.iam_role_arn
}
