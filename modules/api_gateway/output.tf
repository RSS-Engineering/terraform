output "api_id" {
  value = aws_api_gateway_rest_api.rest_api.id
}

output "hostname" {
  value = "${aws_api_gateway_rest_api.rest_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com"
}