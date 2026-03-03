# --- Log Groups ---
resource "aws_cloudwatch_log_group" "ec2_logs" {
  name = "/aws/ec2/webserver"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name = "/aws/vpc/flowlogs"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name = "/ecs/logstash"
  retention_in_days = 30
}

# --- VPC Flow Logs ---
resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
}

# --- Subscription Filter (Log Group -> Kinesis) ---
resource "aws_cloudwatch_log_subscription_filter" "ec2_to_kinesis" {
  name            = "ec2-logs-to-kinesis"
  role_arn        = aws_iam_role.cw_to_kinesis.arn
  log_group_name  = aws_cloudwatch_log_group.ec2_logs.name
  filter_pattern  = "" # Capture everything
  destination_arn = aws_kinesis_stream.siem_stream.arn
}

resource "aws_cloudwatch_log_subscription_filter" "flowlogs_to_kinesis" {
  name            = "flowlogs-to-kinesis"
  role_arn        = aws_iam_role.cw_to_kinesis.arn
  log_group_name  = aws_cloudwatch_log_group.vpc_flow_logs.name
  filter_pattern  = "" 
  destination_arn = aws_kinesis_stream.siem_stream.arn
}
