resource "aws_kinesis_stream" "siem_stream" {
  name             = "${var.project_name}-stream"
  shard_count      = 1
  retention_period = 24

  tags = {
    Name = "${var.project_name}-stream"
  }
}
