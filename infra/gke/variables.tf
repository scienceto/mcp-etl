variable "project_id" {

}

variable "region" {
  default = "us-central1"
}

variable "cluster_name" {
  default = "autopilot-cluster"
}

variable "namespace" {
  default = "default"
}

variable "etl_ksa_name" {
  
}

variable "pubsub_topic_name" {
  default = "mcp-etl-test-topic"
}

variable "pubsub_subscription_name" {
  default = "mcp-etl-test-topic-sub"
}